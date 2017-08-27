#!/usr/bin/perl -w
#
#   rc.pl - remote control script
#
#   This program is free software; you can redistribute it and/or modify it under the
#   terms of the GNU General Public License as published by the Free Software Foundation;
#   either version 3 of the License, or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
#   without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#   See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License along with this program;
#   if not, see <http://www.gnu.org/licenses/>.
#
our $ver = '1.00.07 - 08.03.2017';
my $retc = 0;
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../../../lib";                                                                                                  # use fsi portal modules
use Config::General;
use English;
use Net::MAC;
use File::Basename;

my $rel_path = File::Spec->rel2abs(__FILE__);
my ( $volume, $dirs, $prg ) = File::Spec->splitpath($rel_path);
our $prgname = basename( $prg, '.pl' );

use Log::Log4perl qw(:no_extra_logdie_message :levels);

our %global = (
   "progdir"   => $dirs,
   "errmsg"    => "",
   "rccfgdir"  => $dirs . '../../../etc/sys',
   "logdir"    => $dirs . '../../../logs',
   "logcfgfile"=> $dirs . '../../../etc/log4p_fsi',
   "logquietcfgfile" => $dirs . '../../../etc/log4p_fsi_quiet',
   "logfile"   => "no",
   "quietmode" => "no",
   "loglevel" => 0,
   "logprod"   => 20000,                                                                                                         # choose one of following level for function level
                                                                                                                                 # Loglevel: INFO 20000
                                                                                                                                 # Loglevel: TRACE 5000
                                                                                                                                 # Loglevel: WARN 30000
                                                                                                                                 # Loglevel: ERROR 40000
                                                                                                                                 # Loglevel: DEBUG 10000
);

## Load function files
require "$Bin/../../../lib/func.pl";                                                                                             # some general functions
require "$Bin/rc_help.pl";                                                                                                       # help


if ( $#ARGV eq '-1' ) { help(); }

use Sys::Hostname;
our $host      = hostname;

unless ( -e $global{'logcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logcfgfile'} !\n\n";
   exit(101);
}
unless ( -e $global{'logquietcfgfile'} ) {
   print "\n ERROR: cannot find config file for logs $global{'logquietcfgfile'} !\n\n";
   exit(101);
}


our $flvl     = 0;                                                                                                               # function level
our $ll = " " x $flvl;


## This is so later we can re-parse the command line args later if we need to
our @ARGS    = @ARGV;
our $numargv = @ARGS;
my $counter  = 0;
my $mode     = "none";
my $srvmac   = "none";
our $quietmode = "no";


for ($counter = 0; $counter < $numargv; $counter++) {
    #print(" Argument: $ARGS[$counter]");
    if ($ARGS[$counter] =~ /^-h$/i) {                
       help(); 
    } elsif ($ARGS[$counter] eq "") {                  
        ## Do nothing
    } elsif ( $ARGS[ $counter ] =~ m/^-q$/ ) {
      $quietmode = "yes";
    } elsif ($ARGS[$counter] =~ /^--help/) {           
       help(); 
    } elsif ($ARGS[$counter] =~ /^--do$/) {           
        $counter++;
        if ($ARGS[$counter] && $ARGS[$counter] !~ /^-/) {
            $mode = $ARGS[$counter];
            chomp($mode);
            $mode =~ s/\n|\r//g;
        } else { 
           print("ERROR: The argument after --do was not correct - ignore!\n\n"); 
           $counter--; 
        }
    } elsif ($ARGS[$counter] =~ /^--mac$/) {           
        $counter++;
        if ($ARGS[$counter] && $ARGS[$counter] !~ /^-/) {
            $srvmac = $ARGS[$counter];
            chomp($srvmac);
            $srvmac =~ s/\n|\r//g;
            #print("$ll  found mac: $srvmac");
        } else { 
           print("ERROR: The argument after --mac was not correct - ignore!\n\n"); 
           $counter--; 
        }
   } elsif ( $ARGS[ $counter ] =~ /^-l$/ ) {
      $counter++;
      $global{'logfile'} = "";
      if ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
         while ( $ARGS[ $counter ] && $ARGS[ $counter ] !~ /^-/ ) {
            if ( $global{'logfile'} ) { $global{'logfile'} .= " "; }
            $global{'logfile'} .= $ARGS[ $counter ];
            $counter++;
         }
         $counter--;
         chomp( $global{'logfile'} );
         $global{'logfile'} =~ s/\n|\r//g;
         # print("Logfile: [$global{'logfile'}]\n");
      } else {
         print("ERROR: The argument after -l was no log file name\n\n");
         exit(100);
      }
   } elsif ( $ARGS[ $counter ] =~ m/^-1$/ ) {
      $global{'loglevel'} = $DEBUG;
   } elsif ( $ARGS[ $counter ] =~ m/^--debug$/ ) {
      $global{'loglevel'} = $DEBUG;
   } elsif ( $ARGS[ $counter ] =~ m/^--off$/ ) {
      $global{'loglevel'} = $OFF;
   } elsif ( $ARGS[ $counter ] =~ m/^-0$/ ) {
      $global{'loglevel'} = $INFO;
   } elsif ( $ARGS[ $counter ] =~ m/^--info$/ ) {
      $global{'loglevel'} = $INFO;
   } elsif ( $ARGS[ $counter ] =~ m/^--trace$/ ) {
      $global{'loglevel'} = $TRACE;
   } elsif ( $ARGS[ $counter ] =~ m/^-2$/ ) {
      $global{'loglevel'} = $TRACE;
   } else {
       print("ERROR: Unknown option [$ARGS[$counter]]- ignore\n\n");
   }
}

if ( "$global{'logfile'}" eq "no" ) {   # kein logfile auf command line
   $global{'logfile'} = sprintf "%s../../../logs/%s", $dirs, $prgname;
}

sub get_log_fn { return $global{'logfile'} }
if ( "$global{'quietmode'}" eq "yes" ) {
   Log::Log4perl->init($global{'logquietcfgfile'});
} else {
   Log::Log4perl->init($global{'logcfgfile'});
}
our $logger = Log::Log4perl::get_logger();
if ( $global{'loglevel'} != 0 ) {
   $logger->level($global{'loglevel'});
}


### functions
sub power_off {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   
   my $iloip = shift();
   my $ilouser = shift();
   my $ilopw = shift();
   
   if ($iloip) {
      $logger->debug("$ll   iLO: $iloip");
      my $command = "$global{'progdir'}locfg.pl -s $iloip -u $ilouser -p $ilopw -l $global{'logfile'} -f $global{'progdir'}setoff.xml";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
         $logger->trace("$ll  sleep 3 seconds to wait for hardware to power off");
         sleep 3;
      } else {
         $logger->error("failed cmd [$eo]");
         $global{'errmsg'} = "Cannot power off";
      }
   } else {
      $logger->warn("$ll  no ilo ip found - cannot power off server");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub power_off

sub power_on {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;
   
   my $iloip = shift();
   my $ilouser = shift();
   my $ilopw = shift();
   
   if ($iloip) {
      $logger->debug("$ll   iLO: $iloip");
      my $command = "$global{'progdir'}locfg.pl -s $iloip -u $ilouser -p $ilopw -l $global{'logfile'} -f $global{'progdir'}seton.xml";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $global{'errmsg'} = "Cannot power on";
      }
   } else {
      $logger->warn("$ll  cannot find ilo ip - cannot power on");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub power_on

sub set_boot_hd {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;

   my $iloip = shift();
   my $ilouser = shift();
   my $ilopw = shift();

   if ($iloip) {
      $logger->debug("$ll   iLO: $iloip");
      my $command = "$global{'progdir'}locfg.pl -s $iloip -u $ilouser -p $ilopw -l $global{'logfile'} -f $global{'progdir'}sethdboot.xml";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $global{'errmsg'} = "Cannot set boot hd on";
      }
   } else {
      $logger->warn("$ll  cannot find ilo ip - cannot set hd boot order");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_boot_hd

sub set_boot_nic {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $rc     = 0;

   my $iloip = shift();
   my $ilouser = shift();
   my $ilopw = shift();

   if ($iloip) {
      $logger->debug("$ll  hp server iLO - set boot config");
      $logger->debug("$ll   iLO: $iloip");
      my $command = "$global{'progdir'}locfg.pl -s $iloip -u $ilouser -p $ilopw -l $global{'logfile'} -f $global{'progdir'}setnicboot.xml";
      $logger->trace("$ll  cmd: [$command]");
      my $eo = qx($command  2>&1);
      $retc = $?;
      $retc = $retc >> 8 unless ( $retc == -1 );
      unless ($retc) {
         $logger->trace("$ll  ok");
      } else {
         $logger->error("failed cmd [$eo]");
         $global{'errmsg'} = "Cannot set nic boot on";
      }
   } else {
      $logger->warn("$ll  no ilo ip found - cannot set nic boot order");
   }

   $logger->trace("$ll func end: [$fc]");
   $flvl--;
   return $rc;
} ## end sub set_boot_nic

sub dojob {
   my $fc = ( caller(0) )[ 3 ];
   $flvl++;
   my $ll = " " x $flvl;
   $logger->trace("$ll func start: [$fc]");
   my $retc=0;
   my ( $job, $mac ) = @_;
   
   my %srvcfg_h=();
   
   $logger->trace("$ll  to do: $job");
   $logger->trace("$ll  srv mac: $mac");
   
   if ( -d $global{'rccfgdir'} ) {
      my $srvcfgdir="$global{'rccfgdir'}/$mac";
      if ( -d $srvcfgdir ) {
         $logger->debug("$ll found $srvcfgdir");
         my $srvcfgfile="$srvcfgdir/rc.ini";
         if ( -f $srvcfgfile ) {
            $retc=read_config($srvcfgfile,\%srvcfg_h);
            unless ($retc) {
               if ( defined $srvcfg_h{'rc_type'} ) {
                  if ( $srvcfg_h{'rc_type'} eq "hpilo4" ) {
                     my $pass="";
                     my $ip="";
                     my $user="";
                     if ( defined $srvcfg_h{'ilo_upw'} ) {
                        if ( defined $srvcfg_h{'ilo_upwc'} ) {
                           srand( $srvcfg_h{'ilo_upwc'} );
                           $pass .= chr( ord($_) ^ int( rand(10) ) ) for ( split( '', $srvcfg_h{'ilo_upw'} ) );
                        } else {
                           $logger->error("no user password code given");
                           $retc=13;
                        }
                     } else {
                        $logger->error("no user password given");
                        $retc=12;
                     }
                     unless ($retc) {
                        if ( defined $srvcfg_h{'ilo_ip'} ) {
                           $ip=$srvcfg_h{'ilo_ip'};
                        } else {
                           $logger->error("no ilo ip given");
                           $retc=14;
                        }
                     }
                     unless ($retc) {
                        if ( defined $srvcfg_h{'ilo_u'} ) {
                           $user=$srvcfg_h{'ilo_u'};
                        } else {
                           $logger->error("no ilo user given");
                           $retc=15;
                        }
                     }
                     unless ($retc) {
                        if ( "$mode" eq "poweroff" ) {
                           $retc=power_off($ip,$user,$pass);
                        } elsif ( "$mode" eq "poweron" ) {
                           $retc=power_on($ip,$user,$pass);
                        } elsif ( "$mode" eq "setnic" ) {
                           $retc=set_boot_nic($ip,$user,$pass);
                        } elsif ( "$mode" eq "sethd" ) {
                           $retc=set_boot_hd($ip,$user,$pass);
                        } else {
                           $logger->error("unknown job to do - abort");
                           $retc=5;
                        }  
                     }
                  } else {
                     $logger->error("inappropriate config type $srvcfg_h{'rc_type'} found");
                     $retc=11;
                  }
               } else {
                  $logger->error("no type found in ini file");
                  $retc=10;
               }
            } else {
               $logger->error("cannot read server config ini file");
               $retc=9;
            }
         } else {
            $logger->warn("$ll no server config file $srvcfgfile found");
            $retc=8;
         }
      } else {
         $logger->warn("$ll no server config dir for $mac found");
         $retc=6
      }
   } else {
      $logger->error("no server base config dir exist $global{'rccfgdir'}");
      $retc=7;
   }
   
   $logger->trace("$ll func end: [$fc] - rc=$retc");
   $flvl--;
   return $retc;
}



### main
$logger->info("Starting $prg - version $ver");
if ( "$srvmac" eq "none" ) {
   $logger->error("  no server mac given");
   $retc=3;
} else {
   if ( $srvmac =~ /^([0-9A-Fa-f]{1,2}[\.:-]){5}([0-9A-Fa-f]{1,2})$/ ) {
      $srvmac =~ s/[:|.]/-/g;
      $srvmac    = lc($srvmac);
   } else {
      $logger->error("mac not correct formated - [$srvmac]");
      $retc=4;
   }
}

unless ($retc) {
   if ( "$mode" eq "none" ) {
      $logger->error("  no job given - do not know what to do");
      $retc=2;
   } else {
      $retc=dojob($mode,$srvmac);
   }
}

$logger->info("End $prg - version $ver return code $retc");
exit($retc);
__END__
