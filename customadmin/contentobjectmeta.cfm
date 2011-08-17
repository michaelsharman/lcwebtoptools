<!---
	Name			: contentobjectmeta.cfm
	Author			: Michael Sharman
	Created			: July 26, 2011
	Last Updated		: July 26, 2011
	History			: Initial release (mps 26/07/2011)
	Purpose			: Tool to find information about a farcry content type, based of an objectId (UUID), object title or friendly url (FU)
 --->

<cfimport taglib="/farcry/core/tags/admin/" prefix="admin">
<cfimport taglib="/farcry/core/tags/webskin/" prefix="skin">

<admin:header title="Content Object Meta" />

<cfoutput>
<style type="text/css">
	ul, hr {margin-top: 10px;}
	em {font-style: italic;}
	li {padding-bottom: 10px; margin: 0 0 0 25px; list-style-type: disc;}
	form li {list-style: none; margin: 0;}
	.text {width: 250px; height: 20px;}
	.tbldata {width: 100%; margin-top: 10px;}
	.tbldata th, .tbldata td {padding: 10px; border: 1px solid ##ccc; vertical-align: top;}
	.tbldata th {background-color: ##eee; font-weight: bold;}
</style>

<cfset input = structNew()>
<cfset structAppend(input, form)>
<cfset structAppend(input, URL)>
<cfparam name="input.criteria" default="">
<cfparam name="input.searchType" default="">
<cfset secureTypes = "farUser,farRole,farPermission">

<cfif input.searchType EQ "objectId">
	<!--- Do we think we have a valid objectId (either from the search form of linking from an FU search result etc)? --->
	
	<h3>Object Id</h3>
	<p><a href="customadmin.cfm?module=contentobjectmeta.cfm&plugin=lcwebtoptools">&lt;&lt; Search again</a></p>
	
	<cfif isValid("uuid", input.criteria)>
		
		<cfquery name="qRef" datasource="#application.dsn#">
			SELECT typename
			FROM refObjects
			WHERE ObjectID = <cfqueryparam cfsqltype="cf_sql_varchar" value="#input.criteria#">
		</cfquery>
		
		<cfif qRef.recordCount>
			<!--- Don't show sensitive data, like farUser --->
			<cfif NOT listFindNoCase(secureTypes, qRef.typename)>
				<cfquery name="qTypename" datasource="#application.dsn#">
					SELECT *
					FROM #qRef.typename#
					WHERE ObjectID = <cfqueryparam cfsqltype="cf_sql_varchar" value="#input.criteria#">
				</cfquery>
		
				<cfif qTypename.recordCount>
					<cfset type = createObject("component", application.stcoapi["#qRef.typename#"].packagePath)>
					<cfset contentObject = type.getData(objectId=input.criteria)>
					<cfif qRef.typename NEQ "dmNavigation" AND structKeyExists(application.stcoapi[qRef.typename], "bUseInTree") AND application.stcoapi[qRef.typename].buseintree>
						<!--- Retrieve the navigation data for this tree type content object --->
						<cfset nav = createObject("component", "farcry.core.packages.types.dmNavigation")>
						<cfset contentObjectId = input.criteria>
						<cfif structKeyExists(contentObject, "versionId") AND len(trim(contentObject.versionId))>
							<cfset contentObjectId = contentObject.versionId>
						</cfif>
						<cfset parentNode = nav.getParent(objectId=contentObjectId)>
						<cfif parentNode.recordCount>
							<cfset tree = createObject("component", "farcry.core.packages.farcry.tree")>
							<cfset path = tree.getAncestors(objectId=parentNode.parentId, bIncludeSelf=true)>
						</cfif>
					</cfif>
					<table class="tbldata">
						<tr>
							<th>Typename</th>
							<td>#qRef.typename#</td>
						</tr>
						<cfif isDefined("qTypename.title")>
							<tr>
								<th>Title</th>
								<td>#qTypename.title#</td>
							</tr>
						</cfif>
						<tr>
							<th>ObjectId</th>
							<td>#qTypename.objectId#</td>
						</tr>
						<cfif isDefined("qTypename.status")>
							<tr>
								<th>Status</th>
								<td>#qTypename.status#</td>
							</tr>
						</cfif>
						<tr>
							<th>Tree Type ("Site" tab)?</th>
							<td>#yesNoFormat(structKeyExists(application.stcoapi[qRef.typename], "bUseInTree") AND application.stcoapi[qRef.typename].buseintree)#</td>
						</tr>
						<cfif qRef.typename NEQ "dmNavigation" AND structKeyExists(application.stcoapi[qRef.typename], "bUseInTree") AND application.stcoapi[qRef.typename].buseintree AND parentNode.recordCount>
							<tr>
								<th>Navigation</th>
								<td>
									<cfif path.recordCount>
										<ul>
											<cfloop query="path">
												<li>#repeatString("-", path.currentRow)# #path.objectName#</li>
											</cfloop>
										</ul>
									<cfelse>
										<p>This content object doesn't appear in any navigation</p>
									</cfif>
								</td>
							</tr>
						</cfif>
						<tr>
							<th>Data Dump</th>
							<td><cfdump var="#contentObject#" expand="false"></td>
						</tr>
					</table>		
				</cfif>
			<cfelseif listFindNoCase(secureTypes, qRef.typename)>
				<p><em>#qRef.typename#</em> is a secured content type so we can't show it. Please see an administrator.</p>
			</cfif>
		<cfelse>
			<!--- Nothing found in refObjects, very strange. Double check dmNavigation in case of tree corruption --->
			<cfquery name="q" datasource="#application.dsn#">
				SELECT *
				FROM dmNavigation
				WHERE objectId = <cfqueryparam cfsqltype="cf_sql_varchar" value="#input.criteria#">
			</cfquery>
			<cfif NOT q.recordCount>
				<p>You entered a valid UUID but we couldn't find anything (and we even checked dmNavigation).</p>
			<cfelse>
				<p>We didn't find a record in refObjects which is very strange, however we did find a record in dmNavigation which suggests a tree corruption.</p>
				<cfdump var="#q#" expand="false">
			</cfif>
		</cfif>
	<cfelse>
		<p>Invalid objectId (not a UUID)</p>
	</cfif>

<cfelseif input.searchType EQ "fu" AND len(input.criteria)>
	<!--- A Friendly URL? --->

	<cfquery name="qFU" datasource="#application.dsn#">
		SELECT fu.refobjectid, fu.fuStatus, fu.friendlyURL, ref.typename
		FROM farFU fu
		LEFT OUTER JOIN refObjects ref
		ON fu.refobjectid = ref.objectid
		WHERE friendlyURL LIKE <cfqueryparam cfsqltype="cf_sql_varchar" value="%#input.criteria#%">
		ORDER BY fuStatus DESC, typename, friendlyURL
	</cfquery>

	<h3>Friendly URL</h3>
	<p><a href="customadmin.cfm?module=contentobjectmeta.cfm">&lt;&lt; Search again</a></p>
	<cfif qFU.recordCount>
		<p>We found the following friendly URL records which may match what you're looking for, click an objectId to find more information:</p>
		<table class="tbldata">
			<thead>
				<tr>
					<th>Friendly URL</th>
					<th>ObjectId</th>
					<th>Typename</th>
					<th>FU Approved</th>
				</tr>
			</thead>
			<tbody>
				<cfloop query="qFU">
					<tr>
						<td>#qFU.friendlyURL#</td>
						<td><a href="?#cgi.query_string#&searchType=objectId&criteria=#qFU.refobjectid#">#qFU.refobjectid#</a></td>
						<td>#qFU.typename#</td>
						<td>#yesNoFormat(qFU.fuStatus)#</td>
					</tr>
				</cfloop>			
			</tbody>
		</table>
	<cfelse>
		<p>Nothing found (we assumed you were looking for a friendly URL)</p>
	</cfif>
	
<cfelseif input.searchType EQ "title" AND len(input.criteria)>
	<!--- Vaguely looking for a title --->
	
	<cfquery name="qTypenames" datasource="#application.dsn#">
		SELECT DISTINCT typename 
		FROM refObjects
		ORDER BY typename
	</cfquery>
	
	<cftry>
		<cfset results = structNew()>
		<cfloop query="qTypenames">
			<cfquery name="q" datasource="#application.dsn#">
				SELECT objectId, label
				FROM #qTypenames.typename#
				WHERE label LIKE '%#input.criteria#%'
			</cfquery>
			<cfif q.recordCount>
				<cfloop query="q">
					<cfif NOT structKeyExists(results, qTypenames.typename)>
						<cfset results[qTypenames.typename] = structNew()>
					</cfif>
					<cfset results[qTypenames.typename][q.objectId] = q.label>
				</cfloop>
			</cfif>
		</cfloop>
		<cfif NOT structIsEmpty(results)>
			<h3>Content Title</h3>
			<p>We found the following records which may match what you're looking for, click an objectId to find more information:</p>
			<table class="tbldata">
				<thead>
					<tr>
						<th>Typename</th>
						<th>ObjectId</th>
						<th>Actual Title</th>
					</tr>
				</thead>
				<tbody>
					<cfloop collection="#results#" item="i">
						<cfset numKeys = structCount(results[i])>
						<cfset counter = 0>
						<cfloop collection="#results[i]#" item="j">
							<cfset counter = counter + 1>
							<tr>
								<cfif numKeys EQ 1>
									<td>#i#</td>
								<cfelseif numKeys GT 1 AND counter EQ 1>
									<td rowspan="#numKeys#">#i#</td>
								</cfif>
								<td><a href="?#cgi.query_string#&searchType=objectId&criteria=#j#">#j#</a></td>
								<td>#results[i][j]#</td>
							</tr>
						</cfloop>
					</cfloop>			
				</tbody>
			</table>
		<cfelse>
			<p>We didn't find anything related to <em>#input.criteria#</em></p>
		</cfif>
		<cfcatch type="database">
			<cfdump var="#cfcatch#">
			<cfabort>
		</cfcatch>
	</cftry>

<cfelse>
	<!--- Search form --->
	<h1>Content Object Meta <em>[beta]</em></h1>
	<p>Enter a value in the text box below and select a search type to retrieve any information we can find in the database.</p>
	<ul>
		<li>"Label" will search any label or title, think html or navigation titles.</li>
		<li>"Friendly URL" will search for any part of a URL</li>
		<li>"Object Id" will try to look for <em>any</em> object in the database regardless of "type"</li>
	</ul>
	<p>Wildcards are automatically added to any search term you enter.</p>
	<hr />
	<form id="frmContentObjectMeta" action="" method="post">
		<ul>
			<li>
				<input type="text" name="criteria" id="criteria" value="#input.criteria#" class="text" />
			</li>
			<li>
				<label for="title">
					<input type="radio" name="searchType" id="title" value="title" checked="checked" /> Label
				</label>
			</li>
			<li>
				<label for="fu">
					<input type="radio" name="searchType" id="fu" value="fu" /> Friendly URL
				</label>
			</li>
			<li>
				<label for="objectId">
					<input type="radio" name="searchType" id="objectId" value="objectId" /> Object Id (UUID)
				</label>
			</li>
			<li>
				<input type="submit" name="btnSubmit" id="btnSubmit" value="Search &gt;&gt;" />
			</li>
		</ul>
	</form>	
</cfif>
</cfoutput>

<admin:footer />