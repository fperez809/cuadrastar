#!/usr/bin/perl -w
#---------------------------------------------------------------------------------------------------------#
#
#   simple_star_database_exporter.pl
#
#		This tool exports all content from a Cuadra STAR database and generates the export in a TaggedASCII format.
#
#		The documents are delimited by a header that starts with #### sign, and end in a line that only contains '++++'
#		Each key-value pair is structured according to the format [FIEDLDNAME]: [FIELDVALUE]
#
#		Sample
#				####1 STAREXPORT
#				AUTHOR: Perez, Francis
#				TITLE: Sample Document exported.
#				VOL: 25
#				ISSUE: 2
#				++++
#				
#
#		This tool uses the *ALL export report in conjunction with the DUMP2 page format to generate a key->value export out of STAR,
#		and then it parses that output to generate a clean tagged ascii file.
#
#		This tool does not require any special packages other than those available with core Perl (such as log4perl, etc).  This was done
#		to remove the need from the user to install and configure dependencies.
#      	
#		Assumptions:
#			* The star tools (star, starclean) are usable directly from the command line (i.e. ~star/sys is included in the PATH env variable)
#			* /tmp is available in the system and has enough space to hold the full export.
#			* The source database does not require a password to access the search screen.

#		Limitations:
#			* The list of fields in the source database when concatenated cannot exceed 800 chars (STAR system limit)
#			* This tool will fail if the total content exported is > 2GB. (Another STAR limitation) 
#
#      
#---------------------------------------------------------------------------------------------------------#


use strict;

$| = 1;

#-----------------------------------------------------#
#                   MAIN START                        #
#-----------------------------------------------------#

use constant STAR_EMPTY_FILE_BYTESIZE       => 5;   

if(@ARGV != 4) {
	print "\nUsage: $0 <star_dbname> <star_user> <star_pass> <output_file>\n\n";
	exit(-2);
}

my $star_db 	= $ARGV[0];
my $star_user 	= $ARGV[1];
my $star_pass	= $ARGV[2];
my $outfile 	= $ARGV[3];

my $inline;
my $rec_buffer                      = "";
my $numrecs                         = 0;
my $tmpfile_clean                   = "$outfile.starclean";
my $star_recnum;
my $status;

#-----------------------------------------------------#
#Running STAR Export                                  #
#-----------------------------------------------------#
print "\n--->Running STAR Export\n";
$status = run_star_export({'star_db' => $star_db, 'star_user' => $star_user, 'star_pass' => $star_pass});

if($status =~ /\[FAILURE\]/) {
	die "\nERROR: The STAR Export file could not be generated: (STATUS:$status)";
}

$export_file = $status;

#-----------------------------------------------------#
#Running Starclean                                    #
#-----------------------------------------------------#

print("\n--->Running starclean...\n"); 
$status = system("starclean $export_file $tmpfile_clean");

if($status !~ /^0$/) {
	die "\nERROR: Starclean was not successful in cleaning the file <$export_file> (STATUS:$status)";
}

#------------------------------------------------------------------#
#Conversion of output into a proper tagged ascii key-value format  #
#------------------------------------------------------------------#
print("\n--->Converting from STAR format to tagged ascii...\n");

open(FH_IN, $tmpfile_clean)         or die "ERROR: Could not open file $tmpfile_clean: $!\n";
open(FH_OUT, ">$outfile")           or die "ERROR: Could not open $outfile for output: $!\n";

while($inline = <FH_IN>) {

    if($inline =~ /^--REC--/) {  #Found start of a new export document.
        
        $star_recnum = $inline;
        $star_recnum =~ s/^--REC--//;       
        $numrecs++;  
        chomp($star_recnum);
        
        if($numrecs % 500 == 0) {
            print "   -->$numrecs records processed...\n";
        }
        
		#Flush an existing document buffer to disk.
        if($numrecs > 1) {
            $rec_buffer .= "\n++++"; 
            print FH_OUT "$rec_buffer\n\n";       	
        }
        
		#Populating a new document buffer
        $rec_buffer = "";
        $rec_buffer .= "####$numrecs STAREXPORT\n";
        $rec_buffer .= "STARRN: $star_recnum\n";
        $rec_buffer .= "STARDB: $star_db\n";   

        next;
        
    }   
    
	
    if($inline =~ /^\s/) {			#if the line starts with a space, then appending to buffer as this is a continuation of a field value.
        chomp($rec_buffer);
        $rec_buffer .= "$inline";
    } else {						#This is a new key-value entry - normalizing the field name 
    	$inline =~ s/^([^\s]+)\s*/$1: /;
        $rec_buffer .= "$inline";
    }
  
    
} #end reading documents.

#if the buffer still contains a document, then flushing it to disk.
if(length($rec_buffer) > 0) {
    $rec_buffer .= "\n++++"; 
    print FH_OUT "$rec_buffer\n\n";    
}

close(FH_IN);
close(FH_OUT);

#Cleanup
unlink($tmpfile_clean) if(-e $tmpfile_clean);

print("");
print("\n\n--- All Done --- [Total records exported from $star_db: $numrecs]\n\n");

#---------------------------------------------------------------------------------------#
#--------------------------------END MAIN-----------------------------------------------#
#---------------------------------------------------------------------------------------#


#---------------------------------------------------------------------------------------------------#
#
# run_star_export
#	Handles the generation of an export out of the provided STAR DB with the supplied credentials   
#	This method generates an export macro that first identifies all documents
#	and then exports all fields for each document.
#
#	On Success:
#		Returns the path of the file with the exported documents.
#
#	On Failure:
#		Returns a string that starts with the value "[FAILURE]" followed by the details of the failure.
#       
#---------------------------------------------------------------------------------------------------#
sub run_star_export {

	my $arg_ref = shift;
	my $export_macro = undef;
	my $export_file = undef;
	my $status;
	
	if(defined($arg_ref->{'star_db'}) && defined($arg_ref->{'star_user'}) && defined($arg_ref->{'star_pass'})) {
			
			my $star_db = $arg_ref->{'star_db'};
			my $star_user = $arg_ref->{'star_user'};
			my $star_pass = $arg_ref->{'star_pass'};
			my $base_prefix = "/tmp/starexp.$$";
			
			$export_macro = "$base_prefix.stm";
			$export_file = "$base_prefix.star";
			my $cmd_stdout = "$base_prefix.std.out";
			my $cmd_stderr = "$base_prefix.err.out";
			
			#Building STAR Macro
			open(FH_MACRO, ">$export_macro") or return "[FAILURE] Could not open output file $export_macro: $!\n";
			
			print FH_MACRO "3 $star_db~M\n";
			print FH_MACRO "~[o *ALL~M\n";
			print FH_MACRO "~Y/R 1:9999999999~M\n";			#Selecting all documents.
			print FH_MACRO "~]=Page Format~M~YDUMP2~M\n";
			print FH_MACRO "~E~Y$export_file\n";
			print FH_MACRO "~[w~Me~M~[m~Me~M~[m~Me~M\n";	#Writing file and adding extra steps to ensure the macro will always exit.
			close(FH_MACRO);
			
			print "   [Export macro: $export_macro]\n";
			my $star_export_cmd = "star id=$star_user pw=$star_pass $export_macro";
			
			#Running STAR export cmd (redirecting stdout and stderr to avoid having those printed on the screen with the main script's output)
			$status = system ( "csh -c '($star_export_cmd > $cmd_stdout) >& $cmd_stderr' < /dev/null" );
			
			if($status !~ /^0$/) {
				return "[FAILURE] Invalid status received from the export command <$star_export_cmd> (STATUS:$status)\n";	
			}
			
			if(! -e $export_file || -z $export_file || ((-s $export_file) == STAR_EMPTY_FILE_BYTESIZE)) {
				return "[FAILURE] No content was exported from STAR.  Check the database name provided and make sure the database does have the *ALL report format and DUMP2 page format.";
			} 

	} else {
		return "[FAILURE]: Invalid/Missing arguments provided."
	}
	
	return $export_file;

}


