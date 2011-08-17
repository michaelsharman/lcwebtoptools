<!---
	Name			: databasediff.cfm
	Author			: Michael Sharman
	Created			: September 30, 2010
	Last Updated		: September 30, 2010
	History			: Initial release (mps 30/09/2010)
	Purpose			: Looks for differences in case between mysql table names, and the relevant references in the farcry coapi
					: If differences are found you can attempt to "fix" them by renaming the database tables.
					: Looks for "types", "rules" and "schema" farcry references
					: Runs on MySQL only.
					: Needs "read" access to the information schema
					: Needs "rename" permission
					: Finds instances where tables exist but nothing is found in the coapi (notification only)
 --->

<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin">
<cfimport taglib="/farcry/core/tags/admin/" prefix="admin">

<cfparam name="form.infoSchema" default="" type="string">

<admin:header title="" />

<skin:loadJS id="jquery" />

<skin:htmlHead>
	<cfoutput>
		<style type="text/css">
			table.tblDiff{margin-bottom:10px;}
			table td{font-size:12px;}
			table th{text-align:left;font-size:14px;font-weight:bold;}
			table.tblDiff th, table.tblDiff td{border:1px solid ##ccc;padding:7px;}
			.error{color:##c00;font-weight:bold;font-size:15px;}
			.noDiffs{color:##390;border:1px solid ##390;padding:20px;width:400px;background-color:##e2ffe2;}
			p{margin: 0 0 1.2em;}
			p.note{padding-top:10px;font-size:11px;}
			em{font-style:italic;}
			h1, h2, h3, h4, h5{padding-bottom:5px;}
			ul {margin: .3em 0 1.5em 0;list-style-type:disc;}
			li {line-height: 1.3;padding-left: 18px;position:relative;list-style:disc;}
		</style>
		<script type="text/javascript">
			var Learnosity = {};
			Learnosity.checkAllDiffs = function()
			{
				$('input[name=diffValues]').attr('checked', $('##selectAll').is(':checked'));
			}
		</script>
	</cfoutput>
</skin:htmlHead>

<cfoutput>
	<h1>FarCry / MySQL Diff Utility <em>[beta]</em></h1>
</cfoutput>


<!--- Make sure we have the project database name, needed for information schema lookups --->
<cfif len(form.infoSchema)>
	
	<cfoutput>
		<p>Currently running against <em>#form.infoSchema#</em>, <a href="customadmin.cfm?module=databasediff.cfm&plugin=lcwebtoptools">run against another schema</a></p>
		<hr>
	</cfoutput>

	<!--- "Fix" form submitted...let's do some renaming! --->
	<cfif structKeyExists(form, "btnDoRename")>
		<cfif structKeyExists(form, "diffValues")>
			<!--- Hack time, because we can't rename tables in a non-case sensitive environment (use case is if on a mac which isn't case sensitive, but you want to fix it for linux')
			we need to rename to a temp table...then the proper name --->
			<cfquery name="qRename" datasource="#application.dsn#">
				RENAME TABLE 
				<cfloop list="#form.diffValues#" index="diff">
					<cfif len(application.dbowner)>#application.dbowner#.</cfif>#listLast(diff, "~")# TO #listFirst(diff, "~")#_temp
					, <cfif len(application.dbowner)>#application.dbowner#.</cfif>#listLast(diff, "~")#_temp TO #listFirst(diff, "~")#
					<cfif diff NEQ listLast(form.diffValues)>,</cfif>
				</cfloop>
			</cfquery>		
		<cfelse>
			<p class="error">Dude...you gotta 'check' some diff's to fix :(</p>
		</cfif>
	</cfif>
	<!--- // End the "fix" renaming, load up the diff screen --->

	<!--- Get the cfc 'table' information from the coapi and schema structs --->
	<cfset stTablesToCheck = structNew() />
	<cfloop list="#structKeyList(application.stCoapi)#" index="i">
		<cfset com = application.stCoapi[i] />
		<cfif listFind("type,rule,schema", com.class)>
			<cfset stTablesToCheck[listLast(com.fullname, ".")] = listLast(com.fullname, ".") />
			<!--- Check array tables --->
			<cfif structKeyExists(com, "aJoins") AND arrayLen(com.aJoins)>
				<cfloop from="1" to="#arrayLen(com.aJoins)#" index="j">
					<cfif com.aJoins[j].type EQ "array" AND com.aJoins[j].class EQ "type" AND com.aJoins[j].direction EQ "to">
						<cfset stTablesToCheck["#listLast(com.fullname, ".")#_#com.aJoins[j].property#"] = "#listLast(com.fullname, ".")#_#com.aJoins[j].property#" />
					</cfif>
				</cfloop>
			<cfelseif listLast(com.fullname, ".") EQ "container">
				<!--- For some reason container_aRules isn't coming up. Pretty sure it'll be there for a while so we'll hard code it --->
				<cfset stTablesToCheck["container_aRules"] = "container_aRules" />
			</cfif>
		</cfif>
	</cfloop>
	<cfloop list="#structKeyList(application.schema)#" index="i">
		<cfset com = application.schema[i] />
		<cfset stTablesToCheck[listLast(com.fullname, ".")] = listLast(com.fullname, ".") />
		<!--- Check array tables --->
		<cfif structKeyExists(com, "aJoins") AND arrayLen(com.aJoins)>
			<cfloop from="1" to="#arrayLen(com.aJoins)#" index="j">
				<cfif com.aJoins[j].type EQ "array">
					<cfset stTablesToCheck["#listLast(com.fullname, ".")#_#com.aJoins[j].property#"] = "#listLast(com.fullname, ".")#_#com.aJoins[j].property#" />
				</cfif>
			</cfloop>
		</cfif>
	</cfloop>
	
	<cfset lenTables = structCount(stTablesToCheck) />
	<cfset lTables = structKeyList(stTablesToCheck) />
	
	
	<!--- Grab the database information from the mysql information schema. Obviously your DB user needs permission to SELECT against this! --->
	<cfquery name="qSchema" datasource="#application.dsn#">
		SELECT table_name, table_type, engine FROM information_schema.tables WHERE table_schema = '#form.infoSchema#' ORDER BY table_name; 
	</cfquery>
	
	<!--- Load a comparison struct including missing farcry cfc's (i.e. tables exist but not in farcry (that we can find)) --->
	<cfset stCompare = structNew()>
	<cfset lNotInFC = "">
	<cfset bDiffBetweenFCDB = false>
	<cfloop query="qSchema">
		<cfset stCompare[qSchema.table_name] = structNew()>
		<cfset stCompare[qSchema.table_name]["db"] = qSchema.table_name>
		<cfset stCompare[qSchema.table_name]["found"] = yesNoFormat(listFindNoCase(lTables, qSchema.table_name))>
		<cfif stCompare[qSchema.table_name]["found"]>
			<cfset stCompare[qSchema.table_name]["farcry"] = listGetAt(lTables, listFindNoCase(lTables, qSchema.table_name))>
			<cfset stCompare[qSchema.table_name]["same_case"] = NOT yesNoFormat(compare(qSchema.table_name, stCompare[qSchema.table_name]["farcry"]))>
			<cfif NOT stCompare[qSchema.table_name]["same_case"]>
				<cfset bDiffBetweenFCDB = true>
			</cfif>
		<cfelse>
			<cfset lNotInFC = listAppend(lNotInFC, qSchema.table_name)>
		</cfif>
	</cfloop>
	<cfset lSortedTables = listSort(valueList(qSchema.table_name), "text")>

	
	<!--- Check DB for missing mysql tables --->
	<cfset lNotInDB = "">
	<cfloop list="#lTables#" index="k">
		<cftry>
			<cfquery name="q" datasource="#application.dsn#">
				SELECT 1 FROM <cfif len(application.dbowner)>#application.dbowner#.</cfif>#k#
			</cfquery>
			<cfcatch type="any">
				<cfset lNotInDB = listAppend(lNotInDB, k)>
			</cfcatch>
		</cftry>
	</cfloop>
	
	

	<!--- ********************* Output findings ********************* --->
	<cfoutput>
		<h3>Findings for the <em>#form.infoSchema#</em> schema</h3>
		<p>From what we can see, FarCry thinks you have #lenTables# tables, MySQL currently has #qSchema.recordCount# tables.</p>
		<cfif len(lNotInDB)>
			<h3>MySQL</h3>
			<p>There <cfif listLen(lNotInDB) EQ 1>is 1 table<cfelse>are #listLen(lNotInDB)# tables</cfif> missing from MySQL, maybe you need to head over to the coapi tool and see if you need to deploy anything?</p>
			<p>Missing MySQL tables are that are referenced in FarCry:</p>
			<ul>
				<cfloop list="#lNotInDB#" index="missing">
					<li>#missing#</li>
				</cfloop>
			</ul>
		</cfif>
	
		<cfif len(lNotInFC)>
			<h3>FarCry</h3>
			<p>I can't find the following table references in FarCry (meaning they're in MySQL...but not FarCry), are they custom non-farcry tables? If so then you can ignore them.</p>
			<ul>
				<cfloop list="#lNotInFC#" index="m">
					<li>#m#</li>
				</cfloop>
			</ul>
		</cfif>
		
		<h3>Case differences</h3>
		<cfif bDiffBetweenFCDB>
			<p>We found some "case" differences between FarCry and mysql:</p>
			<p><label for="selectAll"><input type="checkbox" name="selectAll" id="selectAll" value="1" onclick="Learnosity.checkAllDiffs();"> Select all diff's</label></p>
			<form action="" method="post" id="frmFCDiff">
				<table class="tblDiff">
					<thead>
						<th>FarCry</th>
						<th>MySQL</th>
						<th>Fix</th>
					</thead>
					<tbody>
					<cfloop list="#lSortedTables#" index="st">
						<cfif stCompare[st]["found"] AND NOT stCompare[st]["same_case"]>
							<tr>
								<td>#stCompare[st]["farcry"]#</td>
								<td>#stCompare[st]["db"]#</td>
								<td><input type="checkbox" name="diffValues" value="#stCompare[st]['farcry']#~#stCompare[st]['db']#"></td>
							</tr>
						<cfelseif NOT stCompare[st]["found"]>
							<tr>
								<td><em>Not found</em></td>
								<td>#stCompare[st]["db"]#</td>
								<td>&nbsp;</td>
							</tr>
						</cfif>
					</cfloop>
					</tbody>
				</table>
				<input type="hidden" name="infoSchema" value="#form.infoSchema#">
				<input type="submit" name="btnDoRename" value="Rename (fix) MySQL tables *">
			</form>
			<p class="note">* You need <em>RENAME</em> permissions for your database user for this to work.</p>
		<cfelse>
			<p class="noDiffs">Woo hoo!!! No case differences were found. Have a lovely day :)</p>
		</cfif>
	</cfoutput>

<cfelse>

	<cfoutput>
		<p>Looks for differences in case-sensitivity between MySQL table names, and the relevant references in the FarCry coapi. This is kinda important if
			you're running in a case sensitive environment!
		<br />We also look for missing tables in either FarCry or MySQL.</p>
		<p>First we need the name of the actual MySQL project database, this is needed for a schema lookup.</p>
		<form action="" method="post" id="frmSchema">
			<input type="text" name="infoSchema" value="">
			<input type="submit" name="btnInfoSchema" value="Run Diff">
		</form>	
	</cfoutput>

</cfif>

<admin:footer />