
sub help {
   print <<EOM;

             ${colorBold}H E L P for $prgname ${colorNoBold}

  ${colorGreen}remote control of HP iLO server hardware${colorNormal}
  
    ${colorRed}Server to handle${colorNormal}
     --mac <mac>    server with mac 
    
    ${colorRed}Job parameter${colorNormal}
     --do <command> do this with server:
                       - poweroff
                       - poweron
                       - setnic
                       - sethd
    
    ${colorRed}System parameter${colorNormal}
     -q             quiet mode
     -0/1/2         info/debug/trace mode
     -l             logfile
     
    ${colorRed}Return codes${colorNormal}
      0 = ok
      1 = help
      2 = no to do given
      3 = no mac given
      4 = mac not correct formated
      5 = unknown job to do
      6 = no config dir for server found
      7 = no config base dir found
      8 = no server config ini found
      9 = error reading server config ini file
     10 = no type found in ini file
     11 = inappropriate type found (hpilo4)
     12 = no ilo user password given
     13 = no ilo user password code given
     14 = no ilo ip given
     15 = no ilo user given
     
EOM
   exit(1);
} ## end sub help

1;
