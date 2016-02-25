#Simple STAR Database Exporter


This tool exports all content from a Cuadra STAR database and generates the export in a TaggedASCII format.

The documents are delimited by a header that starts with #### and end in a line that only contains '++++'

Each key-value pair is structured according to the format [FIEDLDNAME]: [FIELDVALUE]

	Sample
	####1 STAREXPORT
	AUTHOR: Perez, Francis
	TITLE: Sample Document exported.
	VOL: 25
	ISSUE: 2
	++++

This tool uses the *ALL export report in conjunction with the DUMP2 page format to generate a key->value export out of STAR,
and then it parses that output to generate a clean tagged ascii file.

This tool does not require any special packages other than those available with core Perl (such as log4perl, etc).  This was done to remove the need from the user to install and configure dependencies

	Assumptions:

	* The star tools (star, starclean) are usable directly from the command line (i.e. ~star/sys is included in the PATH env variable)
	
	* /tmp is available in the system and has enough space to hold the full export.
	
	* The source database does not require a password to access the search screen.


	Limitations:
	
	* The list of fields in the source database when concatenated cannot exceed 800 chars (STAR system limit)
	
	* This tool will fail if the total content exported is > 2GB. (Another STAR limitation) 

      
