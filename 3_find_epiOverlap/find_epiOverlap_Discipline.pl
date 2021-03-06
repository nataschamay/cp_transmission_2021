# find_epiOverlap_Discipline.pl
# By Natascha May Thevasagayam, NCID, Singapore

# For determining discipline contact
# Usage: perl find_epiOverlap_Discipline.pl

use List::MoreUtils qw(uniq);

####################
# INPUT FILES
####################
open (ADM, "list_adm");					# Admission data
open (DOC, "list_dateOfCulture");		# Isolate date of culture
open (PATIENTID, "list_patientID");		# Patient IDs
open (LINKEDPAIRS, "list_linkedPairs");	# Transmission pairs

####################
# OUTPUT FILES
####################
open (DISCSum, ">EpiOverlap_Adm_DiscSum");

####################
# Input files are assumed to have headers
####################
$skip_header = <ADM>;
$skip_header = <PATIENTID>;
$skip_header = <LINKEDPAIRS>;
$skip_header = <DOC>;

####################
#Store Admission data
####################
=head
Patient_ID	Age	Gender	Admission Date	Discharge Date	Admission Hospital	Ward	Bed	Discipline	Start Date	Stop Date	Serial number
Patient_14	NA	NA	2017.180336	2017.185800	Hospital_A	Ward_1	Bed_1	general medicine	2017.180336	2017.185800	1
Patient_14	NA	NA	2018.147945	2018.158904	Hospital_A	Ward_2	Bed_2	general surgery	2018.147945	2018.156165	2
Patient_14	NA	NA	2018.147945	2018.158904	Hospital_A	Ward_3	Bed_3	general surgery	2018.156165	2018.158904	3
=cut

while (<ADM>){
	
	# Remove trailing white space
	chomp($_);
	$infile = $_;
	$infile =~ s/\n|\r//; #**sometimes chomp is not enough**#	
	
	# Store data
	@infile_split = split(/\t/,$infile);
	$infile_split[9] = $infile_split[9] + 0;
	$infile_split[10] = $infile_split[10] + 0;

	# Store whole line; Row number is the unique ID
	$HoAdm{$infile_split[11]} = [ @infile_split ];

}
close(ADM);

####################
#Store Patient IDs
####################
#Isolate_ID		PatientID
#E0098			Patient_4
#E0099			Patient_4
#E0100			Patient_6

while (<PATIENTID>){
	chomp($_);
	$infile = $_;
	$infile =~ s/\n|\r//; #**sometimes chomp is not enough**#	
	
	@infile_split = split(/\t/,$infile);
	$HoPatientID{$infile_split[0]} = $infile_split[1];
}
close(PATIENTID);

####################
#Store Date of Culture
####################
while (<DOC>){
	chomp($_);
	$infile = $_;
	$infile =~ s/\n|\r//; #**sometimes chomp is not enough**#
	
	@infile_split = split(/\t/,$infile);
	$HoDOC{$infile_split[0]} = $infile_split[1];
}
close(DOC);


while (<LINKEDPAIRS>){
	chomp($_);
	$linkedpair = $_;
	$linkedpair =~ s/\n|\r//; #**sometimes chomp is not enough**#

	@linkedpair_split = split(/\t/,$linkedpair);

	$recip = $linkedpair_split[0];
	$donor = $linkedpair_split[1];

	$recip_patient = $HoPatientID{$recip};
	$donor_patient = $HoPatientID{$donor};

	#################################################################################
	# Loop thru hash, limit date ranges to risk period and store data for comparison
	#################################################################################
	
	(@recip_hospital,@recip_hospital_ward,@recip_discipline,@recip_start,@recip_stop,@recip_rowNum) = ();
	(@donor_hospital,@donor_hospital_ward,@donor_discipline,@donor_start,@donor_stop,@donor_rowNum) = ();
	
	for $hoa ( keys %HoAdm ) {
	
		($recip_start,$recip_stop,$donor_start,$donor_stop) = ("OutOfRange") x 4;		
		($recipDate_status,$donorDate_status) = ("Original") x 2;

		# All stays of recip
		if ($HoAdm{$hoa}[0] eq $recip_patient && $HoAdm{$hoa}[9] ne "n.a"){
			
			#RECIP_START: Limiting date ranges to risk period boundary
			if($HoAdm{$hoa}[9] <= $HoDOC{$recip}){
					
				if($HoAdm{$hoa}[9] >= $HoDOC{$donor}){
					$recip_start = $HoAdm{$hoa}[9];
				}else{
					if($HoAdm{$hoa}[10] >= $HoDOC{$donor}){
						$recip_start = $HoDOC{$donor};
						$recipDate_status = "Adjusted";
					}else{
						#$recip_start = $recip_start."_OOR"; # For checking: date out of range
					}
				}
			}else{
				#$recip_start = $recip_start."_OOR"; # For checking: date out of range
			}


			#RECIP_STOP: Limiting date ranges to risk period boundary
			if($HoAdm{$hoa}[10] <= $HoDOC{$recip}){
					
				if($HoAdm{$hoa}[10] >= $HoDOC{$donor}){
					$recip_stop = $HoAdm{$hoa}[10];
				}else{
					#$recip_stop = $recip_stop."_OOR"; # For checking: date out of range
				}
			}else{
				if($HoAdm{$hoa}[9] <= $HoDOC{$recip}){
					$recip_stop = $HoDOC{$recip};
					$recipDate_status = "Adjusted";
				}else{
					#$recip_stop = $recip_stop."_OOR"; # For checking: date out of range
				}
			}

			# Store data for comparison
			# From here, anything that is OutOfRange should be ignored. 
			# Start and Stop dates are already adjusted to the risk period boundary. 
			if($recip_start ne "OutOfRange"){

				push @recip_hospital, $HoAdm{$hoa}[5];
				push @recip_hospital_ward, $HoAdm{$hoa}[5]."#".$HoAdm{$hoa}[6];
				push @recip_discipline, $HoAdm{$hoa}[5]."#".$HoAdm{$hoa}[8];

				push @recip_start, $recip_start;
				push @recip_stop, $recip_stop;

				push @recip_rowNum, $HoAdm{$hoa}[11];

				# Check array sizes
				if(@recip_hospital == @recip_hospital_ward && @recip_hospital == @recip_start
					&& @recip_hospital == @recip_stop && @recip_hospital == @recip_rowNum && @recip_hospital == @recip_discipline){
						$recipSize = @recip_hospital;

				}else{
					print "ERROR: $hoa arrays different size\n";
					$recipSize = 0;
				}
			}


		}

		# All stays of donor
		if ($HoAdm{$hoa}[0] eq $donor_patient && $HoAdm{$hoa}[9] ne "n.a"){

			#DONOR_START: Limiting date ranges to risk period boundary
			if($HoAdm{$hoa}[9] >= $HoDOC{$donor}){
					
				if($HoAdm{$hoa}[9] > $HoDOC{$recip}){
					#$donor_start = $donor_start."_OOR"; # For checking: date out of range
				}else{
					$donor_start = $HoAdm{$hoa}[9];
				}
			}else{
				if($HoAdm{$hoa}[10] >= $HoDOC{$donor}){
					$donor_start = $HoDOC{$donor};
					$donorDate_status = "Adjusted";
				}else{
					#$donor_start = $donor_start."_OOR"; # For checking: date out of range
				}
			}


			#DONOR_STOP: Limiting date ranges to risk period boundary
			if($HoAdm{$hoa}[10] >= $HoDOC{$donor}){
					
				if($HoAdm{$hoa}[10] > $HoDOC{$recip}){
					if($HoAdm{$hoa}[9] <= $HoDOC{$recip}){
						$donor_stop = $HoDOC{$recip};
						$donorDate_status = "Adjusted";
					}else{
						#$donor_stop = $donor_stop."_OOR"; # For checking: date out of range
					}
				}else{
					$donor_stop = $HoAdm{$hoa}[10];
				}
			}else{
				#$donor_stop = $donor_stop."_OOR"; # For checking: date out of range
			}

			# Store data for comparison
			# From here, anything that is OutOfRange should be ignored. 
			# Start and Stop dates are already adjusted to the DOC boundary. 
			if($donor_start ne "OutOfRange"){

				push @donor_hospital, $HoAdm{$hoa}[5];
				push @donor_hospital_ward, $HoAdm{$hoa}[5]."#".$HoAdm{$hoa}[6];
				push @donor_discipline, $HoAdm{$hoa}[5]."#".$HoAdm{$hoa}[8];

				push @donor_start, $donor_start;
				push @donor_stop, $donor_stop;

				push @donor_rowNum, $HoAdm{$hoa}[11];

				# Check array sizes
				if(@donor_hospital == @donor_hospital_ward && @donor_hospital == @donor_start
					&& @donor_hospital == @donor_stop && @donor_hospital == @donor_rowNum && @donor_hospital == @donor_discipline){
						$donorSize = @donor_hospital;
						
				}else{
					print "ERROR: $hoa arrays different size\n"; # For checking
				}
			}

		}
		
	}

	$recipSize = 0;
	$donorSize = 0;

	########################
	# DISCIPLINE OVERLAP
	########################
	($statusH1,$statusH2,$statusH3,$statusH4,$statusH5) = ();
	for($r=0;$r<=$#recip_hospital;$r++){

		for($d=0;$d<=$#donor_hospital;$d++){


			if ($recip_discipline[$r] eq $donor_discipline[$d]){

				if ( $donor_start[$d] <= $recip_stop[$r] && $donor_stop[$d] >= $recip_start[$r] ) {

					if ( $donor_start[$d] == $recip_start[$r] && $donor_stop[$d] == $recip_stop[$r] ) {
						# NOTE: the dates have now been adjusted to the DOC boundaries, therefore may not be the same as the original list_adm
						$statusH1 = "Discipline Direct (Exact)";
						$HoENT{$recip}[0] = "Discipline Direct (Exact)";
					}else{

						$statusH2 = "Discipline Direct";
						$HoENT{$recip}[1] = "Discipline Direct";
					}

				}elsif($donor_stop[$d] < $recip_start[$r]){ # Donor should be in hosp before Recip (no overlap; indirect)

					# indirect, so no overlap, but donor_stop should be before recip_start (donor should be in hosp before recip)\
					$statusH3 = "Discipline Indirect";
					$HoENT{$recip}[2] = "Discipline Indirect";

				}else{
					# indirect, so no overlap, but donor_stop should be before recip_start
					$statusH4 = "No Discipline Contact";
					$HoENT{$recip}[3] = "No Discipline Contact"; #(donor&recipReversed)
				}

			}else{
				$statusH4 = "No Discipline Contact";
				$HoENT{$recip}[3] = "No Discipline Contact"; #\[$recip_rowNum[$r]\-$donor_rowNum[$d]\]
			}
		}
	}

	if (length($statusH1) == 0 && $statusH1 eq $statusH2 && $statusH1 eq $statusH3 && $statusH1 eq $statusH4){ 
		$statusH5 = "Date_OOR";
		$HoENT{$recip}[4] = "Date_OOR"; # Donor or recip dates outside of DOC boundary for this comparison; i.e. donorSize/recipSize == 0
	}
	print DISCSum "$recip\t$recip_patient\t$donor\t$donor_patient\t$statusH1\t$statusH2\t$statusH3\t$statusH4\t$statusH5\n";
	
}