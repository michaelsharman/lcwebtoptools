<cfsetting enablecfoutputonly="true" />
<!--- 
|| DESCRIPTION || 
$Description: 	
	This file is run after /core/tags/farcry/_requestScope.cfm
	It enables us to both override the default farcry request scope variables and also add our own
	
	// Developer Mode
	Turning on developer mode will reinitialise the application every page request.  Useful
	if you are constantly changing application metadata, but disastrous on performance.
$

|| DEVELOPER ||
$Developer: Michael Sharman (michael@chapter31.com)$
--->
	
<cfimport taglib="/farcry/core/tags/farcry" prefix="farcry" />

<cfsetting enablecfoutputonly="no">