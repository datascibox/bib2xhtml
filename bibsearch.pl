#!/usr/bin/env perl -T -w

# $Id: bibsearch,v 1.20 1998/02/11 19:22:30 hull Exp hull $
#
# CGI script for search bibliographies.
#
# Copyright 1995, 1996 David Hull.
# David Hull / hull@cs.uiuc.edu / http://www.uiuc.edu/ph/www/dlhull

# Call this script using the HTML form something like:
#
#  <FORM ACTION="/cgi-bin/bibsearch/path/to/database" method="POST">
#  <PRE><SMALL>
#  Keywords: <INPUT TYPE=TEXT NAME="keyword" SIZE=40>
#  Authors:  <INPUT TYPE=TEXT NAME="author" SIZE=40>
#            <INPUT TYPE=SUBMIT VALUE="Submit search"> <INPUT TYPE=RESET> <INPUT TYPE=SUBMIT NAME="help" VALUE="Help">
#  </SMALL></PRE>
#  </FORM>
#
# If the "database" input tag is omitted, $DEFAULT_BIB will be searched.
# It should *always* have a leading "/", even when tilde expansion
# is to be performed.
#
# Note: if the database file specified in the "database"
# input tag contains slashes, they should be encoded as %2F
# to insure that someone's browser does not munge them.
#
# You can also write the URL and put it directly in an HTML file.
# Here's an example:
#
#   <A HREF="/cgi-bin/bibsearch/path/to/database?author=hull"
#   >my publications</A>
#

### Configuration section.

# Path of default bibliography database, if not specified in URL.
$DEFAULT_BIB_PATH = "/usr/dcs/www/www-root/papers/index.html";

# URL of default biblipgraphy database, if not specified in URL.
$DEFAULT_BIB_URL = "http://pertsserver.cs.uiuc.edu/papers/index.html";

### End of configuration section.

%iso_map = (
    "\300", 'A',	# (192) A grave
    "\301", 'A',	# (193) A acute
    "\302", 'A',	# (194) A circumflex
    "\303", 'A',	# (195) A tilde
    "\304", 'A',	# (196) A umlaut
    "\305", 'A',	# (197) A ring
    "\306", 'AE',	# (198) AE ligature
    "\307", 'C',	# (199) C cedilla
    "\310", 'E',	# (200) E grave
    "\311", 'E',	# (201) E acute
    "\312", 'E',	# (202) E circumflex
    "\313", 'E',	# (203) E umlaut
    "\314", 'I',	# (204) I grave
    "\315", 'I',	# (205) I acute
    "\316", 'I',	# (206) I circumflex
    "\317", 'I',	# (207) I umlaut
    "\321", 'N',	# (209) N tilde
    "\322", 'O',	# (210) O grave
    "\323", 'O',	# (211) O acute
    "\324", 'O',	# (212) O circumflex
    "\325", 'O',	# (213) O tilde
    "\326", 'O',	# (214) O umlaut
    "\330", 'O',	# (216) O slash
    "\331", 'U',	# (217) U grave
    "\332", 'U',	# (218) U acute
    "\333", 'U',	# (219) U circumflex
    "\334", 'U',	# (220) U umlaut
    "\335", 'Y',	# (221) Y acute
    "\337", 'ss',	# (223) sz ligature
    "\340", 'a',	# (224) a grave
    "\341", 'a',	# (225) a acute
    "\342", 'a',	# (226) a circumflex
    "\343", 'a',	# (227) a tilde
    "\344", 'a',	# (228) a umlaut
    "\345", 'a',	# (229) a ring
    "\346", 'ae',	# (230) ae ligature
    "\347", 'c',	# (231) c cedilla
    "\350", 'e',	# (232) e grave
    "\351", 'e',	# (233) e acute
    "\352", 'e',	# (234) e circumflex
    "\353", 'e',	# (235) e umlaut
    "\354", 'i',	# (236) i grave
    "\355", 'i',	# (237) i acute
    "\356", 'i',	# (238) i circumflex
    "\357", 'i',	# (239) i umlaut
    "\361", 'n',	# (241) n tilde
    "\362", 'o',	# (242) o grave
    "\363", 'o',	# (243) o acute
    "\364", 'o',	# (244) o circumflex
    "\365", 'o',	# (245) o tilde
    "\366", 'o',	# (246) o umlaut
    "\370", 'o',	# (248) o slash
    "\371", 'u',	# (249) u grave
    "\372", 'u',	# (250) u acute
    "\373", 'u',	# (251) u circumflex
    "\374", 'u',	# (252) u umlaut
    "\375", 'y',	# (253) y acute
    "\377", 'y',	# (255) y umlaut
);
$iso_pat = join('', keys %iso_map);
$iso_pat =~ s/(\W)/\\$1/g;
$iso_pat = '[' . $iso_pat . ']';

&get_args;

if ($in{'help'}) {
    print STDOUT <<_EOF_;
Content-type: text/html

<HTML><HEAD>
<TITLE>Search Help</TITLE>
</HEAD><BODY>
<H1>Search help</H1>
To find a paper, you can specify keywords, authors, or both.
If you specify both keywords and authors, only papers that match
on both the keywords and authors will be found.
Matches are case insensitive.<P>

For the keyword field, you can specify multiple keywords separated by commas.
A paper will match if <EM>any one</EM> of the keywords matches.
A keyword will match only at the beginning of a word, so that
``do'' will match ``domain'' but not ``tandom.''
The keyword search finds words anywhere in the bibliography entry.<P>

For author field, you can specify multiply authors separated by commas.
A paper will match only if <EM>all</EM> of the authors match.
An author must match a whole word, so that ``smith'' will not match
``Smithy.''
Because first names are often abbreviated in bibliographies,
it is safer to search only on last names.<P>
</BODY></HTML>
_EOF_
    exit 0;
}

# Keywords match on any keyword.
# Keywords match only at start of word.
if (defined($in{'keyword'}) && ($in{'keyword'} ne '')) {
    $keyword = $in{'keyword'};
    local(@keywords) = split(/\s*,\s*/, $keyword);
    local($s);

    foreach $s (@keywords) {
	$s =~ s/\s+/\\s\+/g;	# Whitespace matches any amount of whitespace.
	$s =~ s/(\w+)/\\b$1/g;	# Match only at start of words.
    }
    $keyword_pat = join('|', @keywords);
}
# Authors match on all authors.
# Authors match only whole words.
if (defined($in{'author'}) && ($in{'author'} ne "")) {
    $author = $in{'author'};
    @author_pat = split(/\s*,\s*/, &map_iso($author));
    local($s);
    foreach $s (@author_pat) {
	$s =~ s/\W/ /g;		# Change non-word to whitespace.
	$s =~ s/(\w+)/\\b$1\\b/g;	# Match only at whole words.
	$s =~ s/\s+/\\s\+/g;	# Whitespace matches any amount of whitespace.
    }
}

if (defined($ENV{'PATH_INFO'})) {
    $db_url = "http://${ENV{SERVER_NAME}}${ENV{'PATH_INFO'}}";
} else {
    $db_url = $DEFAULT_BIB_URL;
}

if (defined($ENV{'PATH_TRANSLATED'})) {
    $db_file = $ENV{'PATH_TRANSLATED'};
} else {
    $db_file = $DEFAULT_BIB_PATH;
}

# Fake ".nosuch" URL in BASE tag is so that browser caching does not get
# confused (as Netscape 1.1N did without it).
if (!$in{"noheader"}) {
    print STDOUT <<_EOF_;
Content-type: text/html

<HTML><HEAD>
<BASE HREF="$db_url.nosuch">
<TITLE>Search Results</TITLE>
</HEAD>
<BODY>
<H1>Search results for
_EOF_
    print "author `$author'\n" if (defined($author));
    print "keyword `$keyword'\n" if (defined($keyword));
    print STDOUT <<_EOF_;
</H1>
Search performed on <A HREF="$db_url">$db_url</A>.<P>
<HR>
_EOF_
#    print "keyword_pat = $keyword_pat<P>\n";
#    print "author_pat = " . join(', ', @author_pat) . "<P>\n";
}

#&print_env;
#&print_request;

open(FILE, "<$db_file") || die "Can't open $db_file: $!";

$found = 0;

while (1) {
    # Skip to start of bibliography.
    while(<FILE>) {
	last if /^<!-- BEGIN BIBLIOGRAPHY/;
    }

    # Read the next couple of lines to determine what kind of list
    # the bibliography is.
    $open_list = '<UL>';
    $close_list = '</UL>';
line:
    while (<FILE>) {
	if (m/^\<[DU]L/) {
	    $close_list = $open_list = $_;
	    $close_list =~ s/^\<(\w+).*/<\/$1>/;
	}
	last line if (m/^\s*$/);
    }
    print "$open_list";

    $entry = '';
bib_entry:
    while(<FILE>) {
	last bib_entry if (/^<!-- END BIBLIOGRAPHY/);

	if (m/^$/) {
	    if (defined($keyword)) {
		if ($entry !~ m/$keyword_pat/i) {
		    $entry = ''; next bib_entry;
		}
	    }
	    if (defined($author)) {
		if ($entry !~ m/<!-- Authors: ([^-]*)-->/) {
		    $entry = ''; next bib_entry;
		}
		local($bib_authors) = $1;
		foreach $s (@author_pat) {
		    if ($bib_authors !~ m/$s/i) {
			$entry = ''; next bib_entry;
		    }
		}
	    }

	    $found = 1;

	    # Fully qualify local HREFs.
	    $entry =~ s/HREF=\"(\#[^\"]*)\"/HREF=\"$db_url$1\"/g;
	    print STDOUT $entry;
	    $entry = '';
	} else {
	    $entry .= $_;
	}
    }

    if (!$in{"noheader"}) {
	print "$close_list";
    }

    last if eof;
}

if (!$found) {
    print "No matches found.<P>\n";
}

if (!$in{"noheader"}) {
    print STDOUT <<_EOF_;
</BODY></HTML>
_EOF_
}

close(FILE);
exit;

sub print_env {
    local ($key);

    print "Environment:<BR>\n<UL>\n";
    for $key (keys(%ENV)) {
	print "<LI> $key : $ENV{$key}\n";
    }
    print "</UL><P>\n";
}

sub print_request {
    local ($key);

    print "Request:<BR>\n<UL>\n";
    for $key (keys(%in)) {
	print "<LI> $key : $in{$key}\n";
    }
    print "</UL>\n";
}

# Some of the following code stolen from James Tappin's cgi_handlers.pl

sub url_decode {
    foreach (@_) {
	tr/+/ /;
	s/%(..)/pack("c",hex($1))/ge;
    }
    @_;
}

sub get_args {
    local($request) = '';

    return if (!defined($ENV{'REQUEST_METHOD'}));

    if ($ENV{'REQUEST_METHOD'} eq "GET") {
	$request = $ENV{'QUERY_STRING'};
    } elsif ($ENV{'REQUEST_METHOD'} eq "POST") {
	read(STDIN, $request, $ENV{'CONTENT_LENGTH'});
    }

    %in = &url_decode(split(/[&=]/, $request));
}

sub map_iso {
    local ($s) = @_;

    $s =~ s/($iso_pat)/$iso_map{$1}/ge;
    $s;
}
