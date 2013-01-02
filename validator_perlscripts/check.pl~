#!/usr/bin/perl -T
#
# W3C Markup Validation Service
# A CGI script to retrieve and validate a markup file
#
# Copyright 1995-2012 World Wide Web Consortium, (Massachusetts
# Institute of Technology, European Research Consortium for Informatics
# and Mathematics, Keio University). All Rights Reserved.
#
# Originally written by Gerald Oskoboiny <gerald@w3.org>
# for additional contributors, see
# http://dvcs.w3.org/hg/markup-validator/shortlog/tip and
# http://validator.w3.org/about.html#credits
#
# This source code is available under the license at:
#     http://www.w3.org/Consortium/Legal/copyright-software

#
# We need Perl 5.8.0+.
use 5.008;

###############################################################################
#### Load modules. ############################################################
###############################################################################

#
# Pragmas.
use strict;
use warnings;
use utf8;
use Data::Dumper;

package W3C::Validator::MarkupValidator;

#
# Modules.  See also the BEGIN block further down below.
#
# Version numbers given where we absolutely need a minimum version of a given
# module (gives nicer error messages). By default, add an empty import list
# when loading modules to prevent non-OO or poorly written modules from
# polluting our namespace.
#

# Need 3.40 for query string and path info fixes, #4365
use CGI 3.40 qw(-newstyle_urls -private_tempfiles redirect);
use CGI::Carp qw(carp croak fatalsToBrowser);
use Config qw(%Config);
use Config::General 2.32 qw();    # Need 2.32 for <msg 0>, rt.cpan.org#17852
use Encode qw();
use Encode::Alias qw();
use Encode::HanExtra qw();        # for some chinese character encodings,
                                  # e.g gb18030
use File::Spec::Functions qw(catfile rel2abs tmpdir);
use HTML::Encoding 0.52 qw();
use HTML::HeadParser 3.60 qw();    # Needed for HTML5 meta charset workaround
use HTML::Parser 3.24 qw();        # Need 3.24 for $p->parse($code_ref)
use HTML::Template qw();           # Need 2.6 for path param, other things.
                                   # Specifying 2.6 would break with 2.10,
                                   # rt.cpan.org#70190
use HTTP::Headers::Util qw();
use HTTP::Message 1.52 qw();       # Need 1.52 for decoded_content()
use HTTP::Request qw();
use HTTP::Headers::Auth qw();      # Needs to be imported after other HTTP::*.
use JSON 2.00 qw();
use SGML::Parser::OpenSP 0.991 qw();
use URI 1.53 qw();                 # Need 1.53 for secure()
use URI::Escape qw(uri_escape);
use URI::file;
use URI::Heuristic qw();

###############################################################################
#### Constant definitions. ####################################################
###############################################################################

#
# Define global constants
use constant TRUE  => 1;
use constant FALSE => 0;

#
# Tentative Validation Severities.
use constant T_WARN  => 4;    # 0000 0100
use constant T_ERROR => 8;    # 0000 1000

#
# Define global variables.
use vars qw($DEBUG $CFG %RSRC $VERSION);
$VERSION = '1.3';

use constant IS_MODPERL2 =>
    (exists($ENV{MOD_PERL_API_VERSION}) && $ENV{MOD_PERL_API_VERSION} >= 2);

#
# Things inside BEGIN don't happen on every request in persistent environments
# (such as mod_perl); so let's do the globals, eg. read config, here.
BEGIN {
   my $base = $ENV{W3C_VALIDATOR_HOME} || '';

    # Launder data for -T; -AutoLaunder doesn't catch this one.
    if ($base =~ /^(.*)$/) {
        $base = $1;
    }

    #
    # Read Config Files.
    eval {
        my %config_opts = (
            -ConfigFile =>
                ($ENV{W3C_VALIDATOR_CFG} || 'validator.conf'),
            -MergeDuplicateOptions => TRUE,
            -MergeDuplicateBlocks  => TRUE,
            -SplitPolicy           => 'equalsign',
            -UseApacheInclude      => TRUE,
            -IncludeRelative       => TRUE,
            -InterPolateVars       => TRUE,
            -AutoLaunder           => TRUE,
            -AutoTrue              => TRUE,
            -CComments             => FALSE,
            -DefaultConfig         => {
                Protocols => {Allow => 'http,https'},
                Paths     => {
                    Base  => $base,
                    Cache => '',
                },
                External => {HTML5 => FALSE},
            },
        );
        my %cfg = Config::General->new(%config_opts)->getall();
        $CFG = \%cfg;
    };
    if ($@) {
        die <<"EOF";
Could not read configuration.  Set the W3C_VALIDATOR_CFG environment variable
or copy conf/* to /etc/w3c/. Make sure that the configuration file and all
included files are readable by the web server user. The error was:\n'$@'
EOF
    }

    #
    # Check paths in config
    # @@FIXME: This does not do a very good job error-message-wise if
    # a path is missing...
    {
        my %paths = map { $_ => [-d $_, -r _] } $CFG->{Paths}->{Base},
             $CFG->{Paths}->{SGML}->{Library};
        my @_d = grep { not $paths{$_}->[0] } keys %paths;
        my @_r = grep { not $paths{$_}->[1] } keys %paths;
        die "Does not exist or is not a directory: @_d\n"       if scalar(@_d);
        die "Directory not readable (permission denied): @_r\n" if scalar(@_r);
    }

    #
    # Split allowed protocols into a list.
    if (my $allowed = delete($CFG->{Protocols}->{Allow})) {
        $CFG->{Protocols}->{Allow} = [split(/\s*,\s*/, $allowed)];
    }

    # Split available languages into a list
    if (my $langs = delete($CFG->{Languages})) {
        $CFG->{Languages} = [split(/\s+/, $langs)];
    }
    else {

        # Default to english
        $CFG->{Languages} = ["en"];
    }

    {    # Make types config indexed by FPI.
        my $types = {};
        while (my ($key, $value) = each %{$CFG->{Types}}) {
            $types->{$CFG->{Types}->{$key}->{PubID}} = $value;
        }
        $CFG->{Types} = $types;
    }

    #
    # Change strings to internal constants in MIME type mapping.
    while (my ($key, $value) = each %{$CFG->{MIME}}) {
        $CFG->{MIME}->{$key} = 'TBD'
            unless ($value eq 'SGML' || $value eq 'XML');
    }

    #
    # Register Encode aliases.
    while (my ($key, $value) = each %{$CFG->{Charsets}}) {
        Encode::Alias::define_alias($key, $1) if ($value =~ /^[AX] (\S+)/);
    }

    #
    # Set debug flag.
    if ($CFG->{'Allow Debug'}) {
        $DEBUG = TRUE if $ENV{W3C_VALIDATOR_DEBUG} || $CFG->{'Enable Debug'};
    }
    else {
        $DEBUG = FALSE;
    }

    # Read friendly error message file
    # 'en_US' should be replaced by $lang for lang-neg


    eval {
        local $SIG{__DIE__} = undef;
        require Encode::JIS2K;    # for optional extra Japanese encodings
    };

    # Tell libxml to load _only_ our XML catalog.  This is because our entity
    # load jailing may trap the libxml internal default catalog (which is
    # automatically loaded).  Preventing loading that from the input callback
    # will cause libxml to not see the document content at all but to throw
    # weird "Document is empty" errors, at least as of XML::LibXML 1.70 and
    # libxml 2.7.7.  XML_CATALOG_FILES needs to be in effect at XML::LibXML
    # load time which is why we're using "require" here instead of pulling it
    # in with "use" as usual.  And finally, libxml should have support for
    # SGML open catalogs but they don't seem to work (again as of 1.70 and
    # 2.7.7); if we use xml.soc here, no entities seem to end up being resolved
    # from it - so we use a (redundant) XML catalog which works.
    # Note that setting XML_CATALOG_FILES here does not seem to work with
    # mod_perl (it doesn't end up being used by XML::LibXML), therefore we do
    # it in the mod_perl/startup.pl startup file for it too.
    local $ENV{XML_CATALOG_FILES} =
        catfile($CFG->{Paths}->{SGML}->{Library}, 'catalog.xml');
    require XML::LibXML;
    XML::LibXML->VERSION(1.73);    # Need 1.73 for rt.cpan.org #66642

}    # end of BEGIN block.

#
# Get rid of (possibly insecure) $PATH.
delete $ENV{PATH};

#@@DEBUG: Dump $CFG datastructure. Used only as a developer aid.
#use Data::Dumper qw(Dumper);
#print Dumper($CFG);
#exit;
#@@DEBUG;

###############################################################################
#### Process CGI variables and initialize. ####################################
###############################################################################

#
# Create a new CGI object.
my $q = CGI->new;
#print Data::Dumper::Dumper($q);
my $fragment = $ARGV[0];
#print Data::Dumper::Dumper($fragment);
$q->param('fragment',$fragment);
#print Data::Dumper::Dumper($q);
#
# The data structure that will hold all session data.
# @@FIXME This can't be my() as $File will sooner or
# later be undef and add_warning will cause the script
# to die. our() seems to work but has other problems.
# @@FIXME Apparently, this must be set to {} also,
# otherwise the script might pick up an old object
# after abort_if_error_flagged under mod_perl.
our $File = {};

#################################
# Initialize the datastructure. #
#################################

#
# Charset data (casing policy: lowercase early).
$File->{Charset}->{Use}      = ''; # The charset used for validation.
$File->{Charset}->{Auto}     = ''; # Autodetection using XML rules (Appendix F)
$File->{Charset}->{HTTP}     = ''; # From HTTP's "charset" parameter.
$File->{Charset}->{META}     = ''; # From HTML's <meta http-equiv>.
$File->{Charset}->{XML}      = ''; # From the XML Declaration.
$File->{Charset}->{Override} = ''; # From CGI/user override.

#
# Misc simple types.
$File->{Mode} =
    'DTD+SGML';    # Default parse mode is  DTD validation in SGML mode.

# By default, perform validation (we may perform only xml-wf in some cases)
$File->{XMLWF_ONLY} = FALSE;

#
# Listrefs.
$File->{Warnings}   = [];    # Warnings...
$File->{Namespaces} = [];    # Other (non-root) Namespaces.
$File->{Parsers}    = [];    # Parsers used {name, link, type, options}

# By default, doctype-less documents cannot be valid
$File->{"DOCTYPEless OK"}             = FALSE;
$File->{"Default DOCTYPE"}->{"HTML"}  = 'HTML 4.01 Transitional';
$File->{"Default DOCTYPE"}->{"XHTML"} = 'XHTML 1.0 Transitional';

###############################################################################
#### Generate Template for Result. ############################################
###############################################################################

# first we determine the chosen language based on
# 1) lang argument given as parameter (if this language is available)
# 2) HTTP language negotiation between variants available and user-agent choices
# 3) English by default
my $lang = $q->param('lang') || '';
my @localizations;
foreach my $lang_available (@{$CFG->{Languages}}) {
    if ($lang eq $lang_available) {

        # Requested language (from parameters) is available, just use it
        undef @localizations;
        last;
    }
    push @localizations,
        [
        $lang_available, 1,               'text/html', undef,
        'utf-8',         $lang_available, undef
        ];
}

# If language is not chosen yet, use HTTP-based negotiation
if (@localizations) {
    require HTTP::Negotiate;
    $lang = HTTP::Negotiate::choose(\@localizations);
}

# HTTP::Negotiate::choose may return undef e.g if sent Accept-Language: en;q=0
$lang ||= 'en_US';

if ($lang eq "en") {
    $lang = 'en_US';    # legacy
}

$File->{Template_Defaults} = {
    die_on_bad_params => FALSE,
    loop_context_vars => TRUE,
    global_vars       => TRUE,
    case_sensitive    => TRUE,
    path              => [catfile($CFG->{Paths}->{Templates}, $lang)],
    filter => sub { my $ref = shift; ${$ref} = Encode::decode_utf8(${$ref}); },
};
if (IS_MODPERL2()) {
    $File->{Template_Defaults}->{cache} = TRUE;
}
elsif ($CFG->{Paths}->{Cache}) {
    $File->{Template_Defaults}->{file_cache} = TRUE;
    $File->{Template_Defaults}->{file_cache_dir} =
        rel2abs($CFG->{Paths}->{Cache}, tmpdir());
}

undef $lang;

#########################################
# Populate $File->{Opt} -- CGI Options. #
#########################################

#
# Preprocess the CGI parameters.
$q = &prepCGI($File, $q);
#print Data::Dumper::Dumper($q);
#
# Set session switches.
$File->{Opt}->{Outline}        = $q->param('outline') ? TRUE : FALSE;
$File->{Opt}->{'Show Source'}  = $q->param('ss')      ? TRUE : FALSE;
$File->{Opt}->{'Show Tidy'}    = $q->param('st')      ? TRUE : FALSE;
$File->{Opt}->{Verbose}        = $q->param('verbose') ? TRUE : FALSE;
$File->{Opt}->{'Group Errors'} = $q->param('group')   ? TRUE : FALSE;
$File->{Opt}->{Debug}          = $q->param('debug')   ? TRUE : FALSE;
$File->{Opt}->{No200}          = $q->param('No200')   ? TRUE : FALSE;
$File->{Opt}->{Prefill}        = $q->param('prefill') ? TRUE : FALSE;
$File->{Opt}->{'Prefill Doctype'} = $q->param('prefill_doctype') || 'html401';
$File->{Opt}->{Charset} = lc($q->param('charset') || '');
$File->{Opt}->{DOCTYPE} = $q->param('doctype') || '';

$File->{Opt}->{'User Agent'} =
    $q->param('user-agent') &&
    $q->param('user-agent') ne "1" ? $q->param('user-agent') :
                                     "W3C_Validator/$VERSION";
$File->{Opt}->{'User Agent'} =~ tr/\x00-\x09\x0b\x0c-\x1f//d;

if ($File->{Opt}->{'User Agent'} eq 'mobileok') {
    $File->{Opt}->{'User Agent'} =
        'W3C-mobileOK/DDC-1.0 (see http://www.w3.org/2006/07/mobileok-ddc)';
}

$File->{Opt}->{'Accept Header'}          = $q->param('accept')          || '';
$File->{Opt}->{'Accept-Language Header'} = $q->param('accept-language') || '';
$File->{Opt}->{'Accept-Charset Header'}  = $q->param('accept-charset')  || '';
$File->{Opt}->{$_} =~ tr/\x00-\x09\x0b\x0c-\x1f//d
    for ('Accept Header', 'Accept-Language Header', 'Accept-Charset Header');

#
# "Fallback" info for Character Encoding (fbc), Content-Type (fbt),
# and DOCTYPE (fbd). If TRUE, the Override values are treated as
# Fallbacks instead of Overrides.
$File->{Opt}->{FB}->{Charset} = $q->param('fbc') ? TRUE : FALSE;
$File->{Opt}->{FB}->{Type}    = $q->param('fbt') ? TRUE : FALSE;
$File->{Opt}->{FB}->{DOCTYPE} = $q->param('fbd') ? TRUE : FALSE;

#
# If ";debug" was given, let it overrule the value from the config file,
# regardless of whether it's "0" or "1" (on or off), but only if config
# allows the debugging options.
if ($CFG->{'Allow Debug'}) {
    $DEBUG = $q->param('debug') if defined $q->param('debug');
    $File->{Opt}->{Verbose} = TRUE if $DEBUG;
}
else {
    $DEBUG = FALSE;    # The default.
}
$File->{Opt}->{Debug} = $DEBUG;

&abort_if_error_flagged($File);

#
# Get the file and metadata.

if ($q->param('fragment')) {
    $File = &handle_frag($q, $File);
}


#
# Abort if an error was flagged during initialization.
&abort_if_error_flagged($File);

#
# Get rid of the CGI object.
undef $q;

#
# We don't need STDIN any more, so get rid of it to avoid getting clobbered
# by Apache::Registry's idiotic interference under mod_perl.
untie *STDIN;

###############################################################################
#### Output validation results. ###############################################
###############################################################################

if (!$File->{ContentType} && !$File->{'Direct Input'} && !$File->{'Is Upload'})
{
    
}

$File = find_encodings($File);

#
# Decide on a charset to use (first part)
#
if ($File->{Charset}->{HTTP}) {    # HTTP, if given, is authoritative.
    $File->{Charset}->{Use} = $File->{Charset}->{HTTP};
}
elsif ($File->{ContentType} =~ m(^text/(?:[-.a-zA-Z0-9]\+)?xml$)) {

    # Act as if $http_charset was 'us-ascii'. (MIME rules)
    $File->{Charset}->{Use} = 'us-ascii';

    

}
elsif ($File->{Charset}->{XML}) {
    $File->{Charset}->{Use} = $File->{Charset}->{XML};
}
elsif ($File->{BOM} &&
    $File->{BOM} == 2 &&
    $File->{Charset}->{Auto} =~ /^utf-16[bl]e$/)
{
    $File->{Charset}->{Use} = 'utf-16';
}
elsif ($File->{ContentType} =~ m(^application/(?:[-.a-zA-Z0-9]+\+)?xml$)) {
    $File->{Charset}->{Use} = "utf-8";
}
elsif (&is_xml($File) and not $File->{ContentType} =~ m(^text/)) {
    $File->{Charset}->{Use} = 'utf-8';    # UTF-8 (image/svg+xml etc.)
}
$File->{Charset}->{Use} ||= $File->{Charset}->{META};

#
# Handle any Fallback or Override for the charset.
if (charset_not_equal($File->{Opt}->{Charset}, '(detect automatically)')) {

    # charset=foo was given to the CGI and it wasn't "autodetect" or empty.
    #
    # Extract the user-requested charset from CGI param.
    my ($override, undef) = split(/\s/, $File->{Opt}->{Charset}, 2);
    $File->{Charset}->{Override} = lc($override);

    if ($File->{Opt}->{FB}->{Charset}) {    # charset fallback mode
        unless ($File->{Charset}->{Use})
        {    # no charset detected, actual fallback
           
            $File->{Tentative} |= T_ERROR;    # Tag it as Invalid.
            $File->{Charset}->{Use} = $File->{Charset}->{Override};
        }
    }
    else {                                    # charset "hard override" mode
        if (!$File->{Charset}->{Use}) {       # overriding "nothing"
            
            $File->{Tentative} |= T_ERROR;
            $File->{Charset}->{Use} = $File->{Charset}->{Override};
        }
        elsif ($File->{Charset}->{Override} ne $File->{Charset}->{Use}) {

            # Actually overriding something; warn about override.
           
            $File->{Tentative} |= T_ERROR;
            $File->{Charset}->{Use} = $File->{Charset}->{Override};
        }
    }
}

if ($File->{'Direct Input'}) {    #explain why UTF-8 is forced
    
}
unless ($File->{Charset}->{XML} || $File->{Charset}->{META})
{                                 #suggest character encoding info within doc
}

#
# Abort if an error was flagged while finding the encoding.
&abort_if_error_flagged($File);

$File->{Charset}->{Default} = FALSE;
unless ($File->{Charset}->{Use}) {    # No charset given...
    $File->{Charset}->{Use}     = 'utf-8';
    $File->{Charset}->{Default} = TRUE;
    $File->{Tentative} |= T_ERROR;    # Can never be valid.
}
$File->{'Is Valid'} = TRUE;
$File->{Errors}     = [];
$File->{WF_Errors}  = [];
# Always transcode, even if the content claims to be UTF-8
$File = transcode($File);
if($File->{Errors}!=[]){
	
	
}
# Try guessing if it didn't work out
if ($File->{ContentType} eq 'text/html' && $File->{Charset}->{Default}) {
    my $also_tried = 'UTF-8';
    for my $cs (qw(windows-1252 iso-8859-1)) {
        last unless $File->{'Error Flagged'};
        $File->{'Error Flagged'} = FALSE;    # reset
        $File->{Charset}->{Use} = $cs;
       
        $File = transcode($File);
        $also_tried .= ", $cs";
    }
}

# if it still does not work, we abandon hope here
&abort_if_error_flagged($File);

#
# Add a warning if doc is UTF-8 and contains a BOM.
if ($File->{Charset}->{Use} eq 'utf-8' &&
    @{$File->{Content}} &&
    $File->{Content}->[0] =~ m(^\x{FEFF}))
{
    
}

#
# Overall parsing algorithm for documents returned as text/html:
#
# For documents that come to us as text/html,
#
#  1. check if there's a doctype
#  2. if there is a doctype, parse/validate against that DTD
#  3. if no doctype, check for an xmlns= attribute on the first element, or
#     XML declaration
#  4. if no doctype and XML mode, check for XML well-formedness
#  5. otherwise, punt.
#

#
# Override DOCTYPE if user asked for it.
if ($File->{Opt}->{DOCTYPE}) {
    if ($File->{Opt}->{DOCTYPE} !~ /(?:Inline|detect)/i) {
        $File = &override_doctype($File);
    }
    else {

        # Get rid of inline|detect for easy truth value checking later
        $File->{Opt}->{DOCTYPE} = '';
    }
}

# Try to extract a DOCTYPE or xmlns.
$File = &preparse_doctype($File);
#print Data::Dumper::Dumper($File), "\n";

if ($File->{Opt}->{DOCTYPE} eq "HTML5") {
    $File->{DOCTYPE} = "HTML5";
    $File->{Version} = $File->{DOCTYPE};
}

set_parse_mode($File, $CFG);

#
# Sanity check Charset information and add any warnings necessary.
#$File = &charset_conflicts($File);

# before we start the parsing, clean slate

#print Data::Dumper::Dumper($CFG->{External}), "\n";

if (($File->{DOCTYPE} eq "HTML5") or ($File->{DOCTYPE} eq "XHTML5")) {
    if ($CFG->{External}->{HTML5}) {
        $File = &html5_validate($File);
        
    }  else {
        $File->{'Error Flagged'} = TRUE;
        print "error";
        }
}
elsif (($File->{DOCTYPE} eq '') and
    (($File->{Root} eq "svg") or @{$File->{Namespaces}} > 1))
{

    # we send doctypeless SVG, or any doctypeless XML document with multiple
    # namespaces found, to a different engine. WARNING this is experimental.
    if ($CFG->{External}->{CompoundXML}) {
        $File = &compoundxml_validate($File);
        
    }
}
else {
    $File = &dtd_validate($File);
}
&abort_if_error_flagged($File);
if (&is_xml($File)) {
    if ($File->{DOCTYPE} eq "HTML5") {

        # $File->{DOCTYPE} = "XHTML5";
        # $File->{Version} = "XHTML5";
    }
    else {

        # XMLWF check can be slow, skip if we already know the doc can't pass.
        # http://www.w3.org/Bugs/Public/show_bug.cgi?id=9899
        $File = &xmlwf($File) if $File->{'Is Valid'};
    }
    &abort_if_error_flagged($File);
}

#
# Force "XML" if type is an XML type and an FPI was not found.
# Otherwise set the type to be the FPI.
if (&is_xml($File) and not $File->{DOCTYPE} and lc($File->{Root}) ne 'html') {
    $File->{Version} = 'XML';
}
else {
    $File->{Version} ||= $File->{DOCTYPE};
}

#
# Get the pretty text version of the FPI if a mapping exists.
if (my $prettyver = $CFG->{Types}->{$File->{Version}}->{Display}) {
    $File->{Version} = $prettyver;
}

#
# check the received mime type against Allowed mime types
if ($File->{ContentType}) {
    my @allowedMediaType =
        split(/\s+/,
        $CFG->{Types}->{$File->{DOCTYPE}}->{Types}->{Allowed} || '');
    my $usedCTisAllowed;
    if (scalar @allowedMediaType) {
        $usedCTisAllowed = FALSE;
        foreach (@allowedMediaType) {
            $usedCTisAllowed = TRUE if ($_ eq $File->{ContentType});
        }
    }
    else {

        # wedon't know what media type is recommended, so better shut up
        $usedCTisAllowed = TRUE;
    }
    if (!$usedCTisAllowed) {
        
    }
}

#
# Warn about unknown, incorrect, or missing Namespaces.
if ($File->{Namespace}) {
    my $ns = $CFG->{Types}->{$File->{Version}}->{Namespace} || FALSE;

    if (&is_xml($File)) {
        if ($ns eq $File->{Namespace}) {
           
        }
    }
    elsif ($File->{DOCTYPE} ne 'HTML5') {
        
    }
}
else {
    if (&is_xml($File) and $CFG->{Types}->{$File->{Version}}->{Namespace}) {
       
    }
}

## if invalid content, AND if requested, pass through tidy
if (!$File->{'Is Valid'} && $File->{Opt}->{'Show Tidy'}) {
    eval {
        local $SIG{__DIE__} = undef;
        require HTML::Tidy;
        my $tidy = HTML::Tidy->new({config_file => $CFG->{Paths}->{TidyConf}});
        my $cleaned = $tidy->clean(join("\n", @{$File->{Content}}));
        $cleaned = Encode::decode_utf8($cleaned);
        $File->{Tidy} = $cleaned;
    };
    if ($@) {
        (my $errmsg = $@) =~ s/ at .*//s;
        
    }
}
# transcode output from perl's internal to utf-8 and output
#print Encode::encode('UTF-8', "$File->{WF_Errors}");
#msg num char type line
#print keys %{pop(@{$File->{Errors}})};
#print "\n";
#print Data::Dumper::Dumper($File), "\n";
#print Data::Dumper::Dumper($File->{Warnings}), "\n";
#print Data::Dumper::Dumper(scalar @{$File->{Errors}}), "\n";


foreach (@{$File->{Errors}}) {
	$_=$_->{'num'};
}
print join(";",@{$File->{Errors}});
print "";  
#
# Get rid of $File object and exit.
undef $File;
exit;

#############################################################################
# Subroutine definitions
#############################################################################


# TODO: need to bring in fixes from html5_validate() here
sub compoundxml_validate (\$)
{
    my $File = shift;
    my $ua = W3C::Validator::UserAgent->new($CFG, $File);

    push(
        @{$File->{Parsers}},
        {   name    => "Compound XML",
            link    => "http://qa-dev.w3.org/",    # TODO?
            type    => "",
            options => ""
        }
    );

    my $url = URI->new($CFG->{External}->{CompoundXML});
    $url->query("out=xml");

    my $req = HTTP::Request->new(POST => $url);

    if ($File->{Opt}->{DOCTYPE} || $File->{Charset}->{Override}) {

        # Doctype or charset overridden, need to use $File->{Content} in UTF-8
        # because $File->{Bytes} is not affected by the overrides.  This will
        # most likely be a source of errors about internal/actual charset
        # differences as long as our transcoding process does not "fix" the
        # charset info in XML declaration and meta http-equiv (any others?).
        if ($File->{'Direct Input'})
        {    # sane default when using html5 validator by direct input
            $req->content_type("application/xml; charset=UTF-8");
        }
        else {
            $req->content_type("$File->{ContentType}; charset=UTF-8");
        }
        $req->content(Encode::encode_utf8(join("\n", @{$File->{Content}})));
    }
    else {

        # Pass original bytes, Content-Type and charset as-is.
        # We trust that our and validator.nu's interpretation of line numbers
        # is the same (regardless of EOL chars used in the document).

        my @content_type = ($File->{ContentType} => undef);
        push(@content_type, charset => $File->{Charset}->{HTTP})
            if $File->{Charset}->{HTTP};

        $req->content_type(
            HTTP::Headers::Util::join_header_words(@content_type));
        $req->content_ref(\$File->{Bytes});
    }

    $req->content_language($File->{ContentLang}) if $File->{ContentLang};

    # Intentionally using direct header access instead of $req->last_modified
    $req->header('Last-Modified', $File->{Modified}) if $File->{Modified};

    # If not in debug mode, gzip the request (LWP >= 5.817)
    eval { $req->encode("gzip"); } unless $File->{Opt}->{Debug};

    my $res = $ua->request($req);
    if (!$res->is_success()) {
        $File->{'Error Flagged'} = TRUE;
        my $tmpl = &get_error_template($File);
        $tmpl->param(fatal_no_checker      => TRUE);
        $tmpl->param(fatal_missing_checker => 'HTML5 Validator');
        $tmpl->param(fatal_checker_error   => $res->status_line());
    }
    else {
        my $content = &get_content($File, $res);
        return $File if $File->{'Error Flagged'};

        # and now we parse according to
        # http://wiki.whatwg.org/wiki/Validator.nu_XML_Output
        # I wish we could use XML::LibXML::Reader here. but SHAME on those
        # major unix distributions still shipping with libxml2 2.6.16… 4 years
        # after its release
        # …and we could use now as we require libxml2 >= 2.6.21 anyway…
        my $xml_reader = XML::LibXML->new();
        $xml_reader->base_uri($res->base());

        my $xmlDOM;
        eval { $xmlDOM = $xml_reader->parse_string($content); };
        if ($@) {
            my $errmsg = $@;
            $File->{'Error Flagged'} = TRUE;
            my $tmpl = &get_error_template($File);
            $tmpl->param(fatal_no_checker      => TRUE);
            $tmpl->param(fatal_missing_checker => 'HTML5 Validator');
            $tmpl->param(fatal_checker_error   => $errmsg);
            return $File;
        }
        my @nodelist      = $xmlDOM->getElementsByTagName("messages");
        my $messages_node = $nodelist[0];
        my @message_nodes = $messages_node->childNodes;
        foreach my $message_node (@message_nodes) {
            my $message_type = $message_node->localname;
            my ($err, $xml_error_msg, $xml_error_expl);

            if ($message_type eq "error") {
                $err->{type} = "E";
                $File->{'Is Valid'} = FALSE;
            }
            elsif ($message_type eq "info") {

                # by default - we find warnings in the type attribute (below)
                $err->{type} = "I";
            }
            if ($message_node->hasAttributes()) {
                my @attributelist = $message_node->attributes();
                foreach my $attribute (@attributelist) {
                    if ($attribute->name eq "type") {
                        if (($attribute->getValue() eq "warning") and
                            ($message_type eq "info"))
                        {
                            $err->{type} = "W";
                        }

                    }
                    if ($attribute->name eq "last-column") {
                        $err->{char} = $attribute->getValue();
                    }
                    if ($attribute->name eq "last-line") {
                        $err->{line} = $attribute->getValue();
                    }

                }
            }
            my @child_nodes = $message_node->childNodes;
            foreach my $child_node (@child_nodes) {
                if ($child_node->localname eq "message") {
                    $xml_error_msg = $child_node->toString();
                    $xml_error_msg =~ s,</?[^>]*>,,gsi;
                }
                if ($child_node->localname eq "elaboration") {
                    $xml_error_expl = $child_node->toString();
                    $xml_error_expl =~ s,</?elaboration>,,gi;
                    $xml_error_expl =
                        "\n<div class=\"ve xml\">$xml_error_expl</div>\n";
                }
            }

            # formatting the error message for output
            $err->{src}  = "" if $err->{uri};    # TODO...
            $err->{num}  = 'validator.nu';
            $err->{msg}  = $xml_error_msg;
            $err->{expl} = $xml_error_expl;

            if ($err->{msg} =~
                /Using the preset for (.*) based on the root namespace/)
            {
                $File->{DOCTYPE} = $1;
            }
            else {
                push @{$File->{Errors}}, $err;
            }

            # @@ TODO message explanation / elaboration
        }
    }
    return $File;
}

sub html5_validate (\$)
{
    my $File = shift;
    my $ua = W3C::Validator::UserAgent->new($CFG, $File);

    push(
        @{$File->{Parsers}},
        {   name    => "validator.nu",
            link    => "http://validator.nu/",
            type    => "HTML5",
            options => ""
        }
    );

    my $url = URI->new($CFG->{External}->{HTML5});
    $url->query("out=xml");

    my $req = HTTP::Request->new(POST => $url);
    my $ct = &is_xml($File) ? "application/xhtml+xml" : "text/html";

    if ($File->{Opt}->{DOCTYPE} || $File->{Charset}->{Override} ||
        $File->{'Direct Input'})
    {

        # Doctype or charset overridden, need to use $File->{Content} in UTF-8
        # because $File->{Bytes} is not affected by the  overrides.  Note that
        # direct input is always considered an override here.

        &override_charset($File, "UTF-8");

        $ct = $File->{ContentType} unless $File->{'Direct Input'};
        my @ct = ($ct => undef, charset => "UTF-8");
        $ct = HTTP::Headers::Util::join_header_words(@ct);

        $req->content(Encode::encode_utf8(join("\n", @{$File->{Content}})));
    }
    else {

        # Pass original bytes, Content-Type and charset as-is.
        # We trust that our and validator.nu's interpretation of line numbers
        # is the same later when displaying error contexts (regardless of EOL
        # chars used in the document).

        my @ct = ($File->{ContentType} => undef);
        push(@ct, charset => $File->{Charset}->{HTTP})
            if $File->{Charset}->{HTTP};
        $ct = HTTP::Headers::Util::join_header_words(@ct);

        $req->content_ref(\$File->{Bytes});
    }
    $req->content_type($ct);

    $req->content_language($File->{ContentLang}) if $File->{ContentLang};

    # Intentionally using direct header access instead of $req->last_modified
    # (the latter takes seconds since epoch, but $File->{Modified} is an already
    # formatted string).
    $req->header('Last-Modified', $File->{Modified}) if $File->{Modified};

    # Use gzip in non-debug, remote HTML5 validator mode (LWP >= 5.817).
    if (0)
    {
        eval { $req->encode("gzip"); };
    }
    else {
        $req->header('Accept-Encoding', 'identity');
    }
    my $res = $ua->request($req);
    if (!$res->is_success()) {
        $File->{'Error Flagged'} = TRUE;
        print "error";
    }
    else {
        my $content = &get_content($File, $res);
        return $File if $File->{'Error Flagged'};

        # and now we parse according to
        # http://wiki.whatwg.org/wiki/Validator.nu_XML_Output
        # I wish we could use XML::LibXML::Reader here. but SHAME on those
        # major unix distributions still shipping with libxml2 2.6.16… 4 years
        # after its release
        my $xml_reader = XML::LibXML->new();
        $xml_reader->base_uri($res->base());

        my $xmlDOM;
        eval { $xmlDOM = $xml_reader->parse_string($content); };
        if ($@) {
            my $errmsg = $@;
            $File->{'Error Flagged'} = TRUE;
            my $tmpl = &get_error_template($File);
            $tmpl->param(fatal_no_checker      => TRUE);
            $tmpl->param(fatal_missing_checker => 'HTML5 Validator');
            $tmpl->param(fatal_checker_error   => $errmsg);
            return $File;
        }
        my @nodelist      = $xmlDOM->getElementsByTagName("messages");
        my $messages_node = $nodelist[0];
        my @message_nodes = $messages_node->childNodes;
        foreach my $message_node (@message_nodes) {
            my $message_type = $message_node->localname;
            my ($html5_error_msg, $html5_error_expl);
            my $err = {};

            # TODO: non-document errors should receive different/better
            # treatment, but this is better than hiding all problems for now
            # (#6747)
            if ($message_type eq "error" ||
                $message_type eq "non-document-error")
            {
                $err->{type} = "E";
                $File->{'Is Valid'} = FALSE;
            }
            elsif ($message_type eq "info") {

                # by default - we find warnings in the type attribute (below)
                $err->{type} = "I";
            }
            if ($message_node->hasAttributes()) {
                my @attributelist = $message_node->attributes();
                foreach my $attribute (@attributelist) {
                    if ($attribute->name eq "type") {
                        if (($attribute->getValue() eq "warning") and
                            ($message_type eq "info"))
                        {
                            $err->{type} = "W";
                        }

                    }
                    elsif ($attribute->name eq "last-column") {
                        $err->{char} = $attribute->getValue();
                    }
                    elsif ($attribute->name eq "last-line") {
                        $err->{line} = $attribute->getValue();
                    }
                    elsif ($attribute->name eq "url") {
                        &set_error_uri($err, $attribute->getValue());
                    }
                }
            }
            my @child_nodes = $message_node->childNodes;
            foreach my $child_node (@child_nodes) {
                if ($child_node->localname eq "message") {
                    $html5_error_msg = $child_node->textContent();
                }
                elsif ($child_node->localname eq "elaboration") {
                    $html5_error_expl = $child_node->toString();
                    $html5_error_expl =~ s,</?elaboration>,,gi;
                    $html5_error_expl =
                        "\n<div class=\"ve html5\">$html5_error_expl</div>\n";
                }
            }

            # formatting the error message for output

            # TODO: set $err->{src} from extract if we got an URI for the error:
            # http://wiki.whatwg.org/wiki/Validator.nu_XML_Output#The_extract_Element
            # For now, set it directly to empty to prevent report_errors() from
            # trying to populate it from our doc.
            $err->{src} = "" if $err->{uri};

            $err->{num}  = 'html5';
            $err->{msg}  = $html5_error_msg;
            $err->{expl} = $html5_error_expl;
            push @{$File->{Errors}}, $err;

            # @@ TODO message explanation / elaboration
        }
    }
    return $File;
}

sub dtd_validate (\$)
{
    my $File   = shift;
    my $opensp = SGML::Parser::OpenSP->new();

    #
    # By default, use SGML catalog file and SGML Declaration.
    my $catalog = catfile($CFG->{Paths}->{SGML}->{Library}, 'sgml.soc');

    # default parsing options
    my @spopt = qw(valid non-sgml-char-ref no-duplicate);

    #
    # Switch to XML semantics if file is XML.
    if (&is_xml($File)) {
        $catalog = catfile($CFG->{Paths}->{SGML}->{Library}, 'xml.soc');
        push(@spopt, 'xml');
    }
    else {

        # add warnings for shorttags
        push(@spopt, 'min-tag');
    }

    push(
        @{$File->{Parsers}},
        {   name    => "OpenSP",
            link    => "http://openjade.sourceforge.net/",
            type    => "SGML/XML",
            options => join(" ", @spopt)
        }
    );

    #
    # Parser configuration
    $opensp->search_dirs($CFG->{Paths}->{SGML}->{Library});
    $opensp->catalogs($catalog);
    $opensp->show_error_numbers(1);
    $opensp->warnings(@spopt);

    #
    # Restricted file reading is disabled on Win32 for the time
    # being since neither SGML::Parser::OpenSP nor check auto-
    # magically set search_dirs to include the temp directory
    # so restricted file reading would defunct the Validator.
    $opensp->restrict_file_reading(1) unless $^O eq 'MSWin32';

    my $h;    # event handler
    if ($File->{Opt}->{Outline}) {
        $h = W3C::Validator::EventHandler::Outliner->new($opensp, $File, $CFG);
    }
    else {
        $h = W3C::Validator::EventHandler->new($opensp, $File, $CFG);
    }

    $opensp->handler($h);
    $opensp->parse_string(join "\n", @{$File->{Content}});

    # Make sure there are no circular references, otherwise the script
    # would leak memory until mod_perl unloads it which could take some
    # time. @@FIXME It's probably overly careful though.
    $opensp->handler(undef);
    undef $h->{_parser};
    undef $h->{_file};
    undef $h;
    undef $opensp;

    #
    # Set Version to be the FPI initially.
    $File->{Version} = $File->{DOCTYPE};
    return $File;
}

sub xmlwf (\$)
{

    # we should really be using a SAX ErrorHandler, but I can't find a way to
    # make it work with XML::LibXML::SAX::Parser... ** FIXME **
    # ditto, we should try using W3C::Validator::EventHandler, but it's badly
    # linked to opensp at the moment

    my $File      = shift;
    my $xmlparser = XML::LibXML->new();
    $xmlparser->line_numbers(1);
    $xmlparser->validation(0);
    $xmlparser->base_uri($File->{URI})
        unless ($File->{'Direct Input'} || $File->{'Is Upload'});

    push(
        @{$File->{Parsers}},
        {   name    => "libxml2",
            link    => "http://xmlsoft.org/",
            type    => "XML",
            options => ""
        }
    );

    # Restrict file reading similar to what SGML::Parser::OpenSP does.  Note
    # that all inputs go through the callback so if we were passing a
    # URI/filename to the parser, it would be affected as well and would break
    # fetching the initial document.  As long as we pass the doc as string,
    # this should work.
    my $cb = XML::LibXML::InputCallback->new();
    $cb->register_callbacks([\&xml_jail_match, sub { }, sub { }, sub { }]);
    $xmlparser->input_callbacks($cb);

    &override_charset($File, "UTF-8");

    eval { $xmlparser->parse_string(join("\n", @{$File->{Content}})); };

    if (ref($@)) {

        # handle a structured error (XML::LibXML::Error object)

        my $err_obj = $@;
        while ($err_obj) {
            my $err = {};
            &set_error_uri($err, $err_obj->file());
            $err->{src}  = &ent($err_obj->context()) if $err->{uri};
            $err->{line} = $err_obj->line();
            $err->{char} = $err_obj->column();
            $err->{num}  = "libxml2-" . $err_obj->code();
            $err->{type} = "E";
            $err->{msg}  = $err_obj->message();

            $err_obj = $err_obj->_prev();

            unshift(@{$File->{WF_Errors}}, $err);
        }
    }
    elsif ($@) {
        my $xmlwf_errors      = $@;
        my $xmlwf_error_line  = undef;
        my $xmlwf_error_col   = undef;
        my $xmlwf_error_msg   = undef;
        my $got_error_message = undef;
        my $got_quoted_line   = undef;
        foreach my $msg_line (split "\n", $xmlwf_errors) {

            $msg_line =~ s{[^\x0d\x0a](:\d+:)}{\n$1}g;
            $msg_line =~ s{[^\x0d\x0a]+[\x0d\x0a]$}{};

            # first we get the actual error message
            if (!$got_error_message &&
                $msg_line =~ /^(:\d+:)( parser error : .*)/)
            {
                $xmlwf_error_line = $1;
                $xmlwf_error_msg  = $2;
                $xmlwf_error_line =~ s/:(\d+):/$1/;
                $xmlwf_error_msg  =~ s/ parser error :/XML Parsing Error: /;
                $got_error_message = 1;
            }

            # then we skip the second line, which shows the context
            # (we don't use that)
            elsif ($got_error_message && !$got_quoted_line) {
                $got_quoted_line = 1;
            }

            # we now take the third line, with the pointer to the error's
            # column
            elsif (($msg_line =~ /(\s+)\^/) and
                $got_error_message and
                $got_quoted_line)
            {
                $xmlwf_error_col = length($1);
            }

            #  cleanup for a number of bugs for the column number
            if (defined($xmlwf_error_col)) {
                if ((   my $l =
                        length($File->{Content}->[$xmlwf_error_line - 1])
                    ) < $xmlwf_error_col
                    )
                {

                    # http://bugzilla.gnome.org/show_bug.cgi?id=434196
                    #warn("Warning: reported error column larger than line length " .
                    #     "($xmlwf_error_col > $l) in $File->{URI} line " .
                    #     "$xmlwf_error_line, libxml2 bug? Resetting to line length.");
                    $xmlwf_error_col = $l;
                }
                elsif ($xmlwf_error_col == 79) {

                    # working around an apparent odd limitation of libxml which
                    # only gives context for lines up to 80 chars
                    # http://www.w3.org/Bugs/Public/show_bug.cgi?id=4420
                    # http://bugzilla.gnome.org/show_bug.cgi?id=424017
                    $xmlwf_error_col = "> 80";

                    # non-int line number will trigger the proper behavior in
                    # report_error
                }
            }

            # when we have all the info (one full error message), proceed
            # and move on to the next error
            if ((defined $xmlwf_error_line) and
                (defined $xmlwf_error_col) and
                (defined $xmlwf_error_msg))
            {

                # Reinitializing for the next batch of 3 lines
                $got_error_message = undef;
                $got_quoted_line   = undef;

                # formatting the error message for output
                my $err = {};

                # TODO: set_error_uri() (need test case)
                $err->{src}  = "" if $err->{uri};    # TODO...
                $err->{line} = $xmlwf_error_line;
                $err->{char} = $xmlwf_error_col;
                $err->{num}  = 'xmlwf';
                $err->{type} = "E";
                $err->{msg}  = $xmlwf_error_msg;

                push(@{$File->{WF_Errors}}, $err);
                $xmlwf_error_line = undef;
                $xmlwf_error_col  = undef;
                $xmlwf_error_msg  = undef;
            }
        }
    }

    $File->{'Is Valid'} = FALSE if @{$File->{WF_Errors}};
    return $File;
}

#
# Generate HTML report.
sub prep_template ($$)
{
    my $File = shift;
    my $T    = shift;

    #
    # XML mode...
    $T->param(is_xml => &is_xml($File));

    #
    # Upload?
    $T->param(is_upload => $File->{'Is Upload'});

    #
    # Direct Input?
    $T->param(is_direct_input => $File->{'Direct Input'});

    #
    # The URI...
    $T->param(file_uri => $File->{URI});

    #
    # HTTPS note?
    $T->param(file_https_note => $File->{'Is Upload'} ||
            $File->{'Direct Input'} ||
            URI->new($File->{URI})->secure());

    #
    # Set URL for page title.
    $T->param(page_title_url => $File->{URI});

    #
    # Metadata...
    $T->param(file_modified    => $File->{Modified});
    $T->param(file_server      => $File->{Server});
    $T->param(file_size        => $File->{Size});
    $T->param(file_contenttype => $File->{ContentType});
    $T->param(file_charset     => $File->{Charset}->{Use});
    $T->param(file_doctype     => $File->{DOCTYPE});

    #
    # Output options...
    $T->param(opt_show_source  => $File->{Opt}->{'Show Source'});
    $T->param(opt_show_tidy    => $File->{Opt}->{'Show Tidy'});
    $T->param(opt_show_outline => $File->{Opt}->{Outline});
    $T->param(opt_verbose      => $File->{Opt}->{Verbose});
    $T->param(opt_group_errors => $File->{Opt}->{'Group Errors'});
    $T->param(opt_no200        => $File->{Opt}->{No200});

    # Root Element
    $T->param(root_element => $File->{Root});

    # Namespaces...
    $T->param(file_namespace => $File->{Namespace});

    # Non-root ones; unique, preserving occurrence order
    my %seen_ns = ();
    $seen_ns{$File->{Namespace}}++ if defined($File->{Namespace});
    my @nss =
        map { $seen_ns{$_}++ == 0 ? {uri => $_} : () } @{$File->{Namespaces}};
    $T->param(file_namespaces => \@nss) if @nss;

    if ($File->{Opt}->{DOCTYPE}) {
        my $over_doctype_param = "override doctype $File->{Opt}->{DOCTYPE}";
        $T->param($over_doctype_param => TRUE);
    }

    if ($File->{Opt}->{Charset}) {
        my $over_charset_param = "override charset $File->{Opt}->{Charset}";
        $T->param($over_charset_param => TRUE);
    }

    # Allow content-negotiation
    if ($File->{Opt}->{'Accept Header'}) {
        $T->param('accept' => $File->{Opt}->{'Accept Header'});
    }
    if ($File->{Opt}->{'Accept-Language Header'}) {
        $T->param(
            'accept-language' => $File->{Opt}->{'Accept-Language Header'});
    }
    if ($File->{Opt}->{'Accept-Charset Header'}) {
        $T->param('accept-charset' => $File->{Opt}->{'Accept-Charset Header'});
    }
    if ($File->{Opt}->{'User Agent'}) {
        $T->param('user-agent' => $File->{Opt}->{'User Agent'});
    }
    if ($File->{'Error Flagged'}) {
        $T->param(fatal_error => TRUE);
    }
}



#
# Output "This page is Valid" report.


#
# Proxy authentication requests.
# Note: expects the third argument to be a hash ref (see HTTP::Headers::Auth).
sub authenticate
{
    my $File       = shift;
    my $resource   = shift;
    my $authHeader = shift || {};

    my $realm = $resource;
    $realm =~ s([^\w\d.-]*){}g;

    while (my ($scheme, $header) = each %$authHeader) {
        my $origrealm = $header->{realm};
        if (not defined $origrealm or $scheme !~ /^(?:basic|digest)$/i) {
            delete($authHeader->{$scheme});
            next;
        }
        $header->{realm} = "$realm-$origrealm";
    }

    my $headers = HTTP::Headers->new(Connection => 'close');
    $headers->www_authenticate(%$authHeader);
    $headers = $headers->as_string();
    chomp($headers);

    my $tmpl = &get_template($File, 'http_401_authrequired.tmpl');
    $tmpl->param(http_401_headers => $headers);
    $tmpl->param(http_401_url     => $resource);

    print Encode::encode('UTF-8', $tmpl->output );
    exit;    # Further interaction will be a new HTTP request.
}

#
# Fetch an URL and return the content and selected meta-info.

#
# Handle uploaded file and return the content and selected meta-info.
sub handle_frag
{
    my $q    = shift;    # The CGI object.
    my $File = shift;    # The master datastructure.

    $File->{Bytes}          = $q->param('fragment');
    $File->{Mode}           = 'TBD';
    $File->{Modified}       = '';
    $File->{Server}         = '';
    $File->{Size}           = '';
    $File->{ContentType}    = '';                           # @@TODO?
    $File->{URI}            = 'upload://Form Submission';
    $File->{'Is Upload'}    = FALSE;
    $File->{'Direct Input'} = TRUE;
    $File->{Charset}->{HTTP} =
        "utf-8";    # by default, the form accepts utf-8 chars

    if ($File->{Opt}->{Prefill}) {

        # we surround the HTML fragment with some basic document structure
        my $prefill_Template;
        if ($File->{Opt}->{'Prefill Doctype'} eq 'html401') {
            $prefill_Template = &get_template($File, 'prefill_html401.tmpl');
        }
        else {
            $prefill_Template = &get_template($File, 'prefill_xhtml10.tmpl');
        }
        $prefill_Template->param(fragment => $File->{Bytes});
        $File->{Bytes} = $prefill_Template->output();

        # Let's force the view source so that the user knows what we've put
        # around their code.
        $File->{Opt}->{'Show Source'} = TRUE;

        # Ignore doctype overrides (#5132).
        $File->{Opt}->{DOCTYPE} = 'Inline';
    }

    return $File;
}

#
# Parse a Content-Type and parameters. Return document type and charset.
sub parse_content_type
{
    my $File         = shift;
    my $Content_Type = shift;
    my $url          = shift;
    my $charset      = '';

    my ($ct) = lc($Content_Type) =~ /^\s*([^\s;]*)/g;

    my $mode = $CFG->{MIME}->{$ct} || $ct;

    $charset = HTML::Encoding::encoding_from_content_type($Content_Type);

    if (index($mode, '/') != -1) {   # a "/" means it's unknown or we'd have a mode here.
        if ($ct eq 'text/css' and defined $url) {
            print redirect
                'http://jigsaw.w3.org/css-validator/validator?uri=' .
                uri_escape $url;
            exit;
        }
        elsif ($ct eq 'application/atom+xml' and defined $url) {
            print redirect 'http://validator.w3.org/feed/check.cgi?url=' .
                uri_escape $url;
            exit;
        }
        elsif ($ct =~ m(^application/.+\+xml$)) {

            # unknown media types which should be XML - we give these a try
            $mode = "XML";
        }
        else {
            $File->{'Error Flagged'} = TRUE;
            my $tmpl = &get_error_template($File);
            $tmpl->param(fatal_mime_error => TRUE);
            $tmpl->param(fatal_mime_ct    => $ct);
        }
    }

    return $mode, $ct, $charset;
}

#
# Get content with Content-Encodings decoded from a response.
sub get_content ($$)
{
    my $File = shift;
    my $res  = shift;

    my $content;
    eval {
        $content = $res->decoded_content(charset => 'none', raise_error => 1);
    };
    if ($@) {
        (my $errmsg = $@) =~ s/ at .*//s;
        my $cenc = $res->header("Content-Encoding");
        my $uri  = $res->request->uri;
        $File->{'Error Flagged'} = TRUE;
        my $tmpl = &get_error_template($File);
        $tmpl->param(fatal_decode_error  => TRUE);
        $tmpl->param(fatal_decode_errmsg => $errmsg);
        $tmpl->param(fatal_decode_cenc   => $cenc);

        # Include URI because it might be a subsystem (eg. HTML5 validator) one
        $tmpl->param(fatal_decode_uri => $uri);
    }

    return $content;
}

#
# Check recursion level and enforce Max Recursion limit.
sub check_recursion ($$)
{
    my $File = shift;
    my $res  = shift;

    # Not looking at our own output.
    return unless defined $res->header('X-W3C-Validator-Recursion');

    my $lvl = $res->header('X-W3C-Validator-Recursion');
    return unless $lvl =~ m/^\d+$/;    # Non-digit, i.e. garbage, ignore.

    if ($lvl >= $CFG->{'Max Recursion'}) {
        print redirect $File->{Env}->{'Home Page'};
    }
    else {

        # Increase recursion level in output.
        &get_template($File, 'result.tmpl')->param(depth => $lvl++);
    }
}

#
# XML::LibXML::InputCallback matcher using our SGML search path jail.
sub xml_jail_match
{
    my $arg = shift;

    # Ensure we have a file:// URI if we get a file.
    my $uri = URI->new($arg);
    if (!$uri->scheme()) {
        $uri = URI::file->new_abs($arg);
    }
    $uri = $uri->canonical();

    # Do not trap non-file URIs.
    return 0 unless ($uri->scheme() eq "file");

    # Do not trap file URIs within our jail.
    for my $dir ($CFG->{Paths}->{SGML}->{Library},
        split(/\Q$Config{path_sep}\E/o, $ENV{SGML_SEARCH_PATH} || ''))
    {
        next unless $dir;
        my $dir_uri = URI::file->new_abs($dir)->canonical()->as_string();
        $dir_uri =~ s|/*$|/|;    # ensure it ends with a slash
        return 0 if ($uri =~ /^\Q$dir_uri\E/);
    }

    # We have a match (a file outside the jail).
    return 1;
}

#
# Escape text to be included in markup comment.
sub escape_comment
{
    local $_ = shift;
    return '' unless defined;
    s/--/- /g;
    return $_;
}

#
# Return $_[0] encoded for HTML entities (cribbed from merlyn).
#
# Note that this is used both for HTML and XML escaping (so e.g. no &apos;).
#
sub ent
{
    my $str = shift;
    return '' unless defined($str);    # Eliminate warnings

    # should switch to hex sooner or later
    $str =~ s/&/&#38;/g;
    $str =~ s/</&#60;/g;
    $str =~ s/>/&#62;/g;
    $str =~ s/"/&#34;/g;
    $str =~ s/'/&#39;/g;

    return $str;
}

#
# Truncate source lines for report.
# Expects 1-based column indexes.
sub truncate_line
{
    my $line   = shift;
    my $col    = shift;
    my $maxlen = 80;      # max line length to truncate to

    my $diff = length($line) - $maxlen;

    # Don't truncate at all if it fits.
    return ($line, $col) if ($diff <= 0);

    my $start = $col - int($maxlen / 2);
    if ($start < 0) {

        # Truncate only from end of line.
        $start = 0;
        $line = substr($line, $start, $maxlen - 1) . '…';
    }
    elsif ($start > $diff) {

        # Truncate only from beginning of line.
        $start = $diff;
        $line = '…' . substr($line, $start + 1);
    }
    else {

        # Truncate from both beginning and end of line.
        $line = '…' . substr($line, $start + 1, $maxlen - 2) . '…';
    }

    # Shift column if we truncated from beginning of line.
    $col -= $start;

    return ($line, $col);
}

#
# Suppress any existing DOCTYPE by commenting it out.
sub override_doctype
{
    my $File = shift;

    my ($dt) =
        grep { $_->{Display} eq $File->{Opt}->{DOCTYPE} }
        values %{$CFG->{Types}};

    # @@TODO: abort/whine about unrecognized doctype if $dt is undef.;
    my $pubid = $dt->{PubID};
    my $sysid = $dt->{SysID};
    my $name  = $dt->{Name};

    # The HTML5 PubID is a fake, reset it out of the way.
    $pubid = undef if ($pubid eq 'HTML5');

    # We don't have public/system ids for all types.
    my $dtd = "<!DOCTYPE $name";
    if ($pubid) {
        $dtd .= qq( PUBLIC "$pubid");
        $dtd .= qq( "$sysid") if $sysid;
    }
    elsif ($sysid) {
        $dtd .= qq( SYSTEM "$sysid");
    }
    $dtd .= '>';

    my $org_dtd      = '';
    my $HTML         = '';
    my $seen_doctype = FALSE;

    my $declaration = sub {
        my ($tag, $text) = @_;
        if ($seen_doctype || uc($tag) ne '!DOCTYPE') {
            $HTML .= $text;
            return;
        }

        $seen_doctype = TRUE;

        $org_dtd = &ent($text);
        ($File->{Root}, undef, $File->{DOCTYPE}) = $text =~
            /<!DOCTYPE\s+(\w[\w\.-]+)(?:\s+(?:PUBLIC|SYSTEM)\s+(['"])(.*?)\2)?\s*>/si;

        $File->{DOCTYPE} = 'HTML5'
            if (
            lc($File->{Root} || '') eq 'html' &&
            (!defined($File->{DOCTYPE}) ||
                $File->{DOCTYPE} eq 'about:legacy-compat')
            );

        # No Override if Fallback was requested, or if override is the same as
        # detected
        my $known = $CFG->{Types}->{$File->{DOCTYPE}};
        if ($File->{Opt}->{FB}->{DOCTYPE} or
            ($known && $File->{Opt}->{DOCTYPE} eq $known->{Display}))
        {
            $HTML .= $text;    # Stash it as is...
        }
        else {
            $HTML .= "$dtd<!-- " . &escape_comment($text) . " -->";
        }
    };

    my $start_element = sub {
        my $p = shift;
        # Sneak chosen doctype before the root elt if none replaced thus far.
        $HTML .= $dtd unless $seen_doctype;
        $HTML .= shift;
        # We're done with this handler.
        $p->handler(start => undef);
    };

    HTML::Parser->new(
        default_h => [sub { $HTML .= shift }, 'text'],
        declaration_h => [$declaration,   'tag,text'],
        start_h       => [$start_element, 'self,text']
    )->parse(join "\n", @{$File->{Content}})->eof();

    $File->{Content} = [split /\n/, $HTML];

    if ($seen_doctype) {
        my $known = $CFG->{Types}->{$File->{DOCTYPE}};
        unless ($File->{Opt}->{FB}->{DOCTYPE} or
            ($known && $File->{Opt}->{DOCTYPE} eq $known->{Display}))
        {
            
            $File->{Tentative} |= T_ERROR;    # Tag it as Invalid.
        }
    }
    else {
        if ($File->{"DOCTYPEless OK"}) {
            
        }
        elsif ($File->{Opt}->{FB}->{DOCTYPE}) {
            
            $File->{Tentative} |= T_ERROR;    # Tag it as Invalid.
        }
        else {
            
            $File->{Tentative} |= T_ERROR;    # Tag it as Invalid.
        }
    }

    return $File;
}

#
# Override inline charset declarations, for use e.g. when passing
# transcoded results to external parsers that use them.
sub override_charset ($$)
{
    my ($File, $charset) = @_;

    my $ws = qr/[\x20\x09\x0D\x0A]/o;
    my $cs = qr/[A-Za-z][a-zA-Z0-9_-]+/o;

    my $content = join("\n", @{$File->{Content}});

    # Flatten newlines (so that we don't end up changing line numbers while
    # overriding) and comment-escape a string.
    sub escape_original ($)
    {
        my $str = shift;
        $str =~ tr/\r\n/ /;
        return &escape_comment($str);
    }

    # <?xml encoding="charset"?>
    $content =~ s/(
              (^<\?xml\b[^>]*?${ws}encoding${ws}*=${ws}*(["']))
              (${cs})
              (\3.*?\?>)
          )/lc($4) eq lc($charset) ?
              "$1" : "$2$charset$5<!-- " . &escape_original($1) . " -->"/esx;

    # <meta charset="charset">
    $content =~ s/(
              (<meta\b[^>]*?${ws}charset${ws}*=${ws}*["']?${ws}*)
              (${cs})
              (.*?>)
          )/lc($3) eq lc($charset) ?
              "$1" : "$2$charset$4<!-- " . &escape_original($1) . " -->"/esix;

    # <meta http-equiv="content-type" content="some/type; charset=charset">
    $content =~ s/(
              (<meta\b[^>]*${ws}
                  http-equiv${ws}*=${ws}*["']?${ws}*content-type\b[^>]*?${ws}
                  content${ws}*=${ws}*["']?[^"'>]+?;${ws}*charset${ws}*=${ws}*)
              (${cs})
              (.*?>)
          )/lc($3) eq lc($charset) ?
              "$1" : "$2$charset$4<!-- " . &escape_original($1) . " -->"/esix;

    # <meta content="some/type; charset=charset" http-equiv="content-type">
    $content =~ s/(
              (<meta\b[^>]*${ws}
                  content${ws}*=${ws}*["']?[^"'>]+?;${ws}*charset${ws}*=${ws}*)
              (${cs})
              ([^>]*?${ws}http-equiv${ws}*=${ws}*["']?${ws}*content-type\b.*?>)
          )/lc($3) eq lc($charset) ?
              "$1" : "$2$charset$4<!-- " . &escape_original($1) . " -->"/esix;

    $File->{Content} = [split /\n/, $content];
}

sub set_error_uri ($$)
{
    my ($err, $uri) = @_;

    # We want errors in the doc that was validated to appear without
    # $err->{uri}, and non-doc errors with it pointing to the external entity
    # or the like where the error is.  This usually works as long as we're
    # passing docs to parsers as strings, but S::P::O (at least as of 0.994)
    # seems to give us "3" as the FileName in those cases so we try to filter
    # out everything that doesn't look like a useful URI.
    if ($uri && index($uri, '/') != -1) {

        # Mask local file paths
        my $euri = URI->new($uri);
        if (!$euri->scheme() || $euri->scheme() eq 'file') {
            $err->{uri_is_file} = TRUE;
            $err->{uri}         = ($euri->path_segments())[-1];
        }
        else {
            $err->{uri} = $euri->canonical();
        }
    }
}

#
# Generate a HTML report of detected errors.
sub report_errors ($)
{
    my $File   = shift;
    my $Errors = [];
    my %Errors_bytype;
    my $number_of_errors   = 0;
    my $number_of_warnings = 0;
    my $number_of_info     = 0;

    # for the sake of readability, at least until the xmlwf errors have
    # explanations, we push the errors from the XML parser at the END of the
    # error list.
    push @{$File->{Errors}}, @{$File->{WF_Errors}};

    if (scalar @{$File->{Errors}}) {
        foreach my $err (@{$File->{Errors}}) {
            my $col = 0;

            # Populate source/context for errors in our doc that don't have it
            # already.  Checkers should always have populated $err->{src} with
            # _something_ for non-doc errors.
            if (!defined($err->{src})) {
                my $line = undef;

                # Avoid truncating lines that do not exist.
                if (defined($err->{line}) &&
                    $File->{Content}->[$err->{line} - 1])
                {
                    if (defined($err->{char}) && $err->{char} =~ /^[0-9]+$/) {
                        ($line, $col) =
                            &truncate_line(
                            $File->{Content}->[$err->{line} - 1],
                            $err->{char});
                        $line = &mark_error($line, $col);
                    }
                    elsif (defined($err->{line})) {
                        $col = length($File->{Content}->[$err->{line} - 1]);
                        $col = 80 if ($col > 80);
                        ($line, $col) =
                            &truncate_line(
                            $File->{Content}->[$err->{line} - 1], $col);
                        $line = &ent($line);
                        $col  = 0;
                    }
                }
                else {
                    $col = 0;
                }
                $err->{src} = $line;
            }

            my $explanation = "";
            if ($err->{expl}) {

            }
            else {
                if ($err->{num}) {
                    my $num = $err->{num};
                    $explanation .= Encode::decode_utf8(
                        "\n    $RSRC{msg}->{$num}->{verbose}\n")
                        if exists $RSRC{msg}->{$num} &&
                            exists $RSRC{msg}->{$num}->{verbose};
                    my $_msg = $RSRC{msg}->{nomsg}->{verbose};
                    $_msg =~ s/<!--MID-->/$num/g;
                    if (($File->{'Is Upload'}) or ($File->{'Direct Input'})) {
                        $_msg =~ s/<!--URI-->//g;
                    }
                    else {
                        my $escaped_uri = uri_escape($File->{URI});
                        $_msg =~ s/<!--URI-->/$escaped_uri/g;
                    }

                    # The send feedback plea.
                    $explanation = "    $_msg\n$explanation";
                    $explanation =~ s/<!--#echo\s+var="relroot"\s*-->//g;
                }
                $err->{expl} = $explanation;
            }

            $err->{col} = ' ' x $col;
            if ($err->{type} eq 'I') {
                $err->{class}         = 'msg_info';
                $err->{err_type_err}  = 0;
                $err->{err_type_warn} = 0;
                $err->{err_type_info} = 1;
                $number_of_info += 1;
            }
            elsif ($err->{type} eq 'E') {
                $err->{class}         = 'msg_err';
                $err->{err_type_err}  = 1;
                $err->{err_type_warn} = 0;
                $err->{err_type_info} = 0;
                $number_of_errors += 1;
            }
            elsif (($err->{type} eq 'W') or ($err->{type} eq 'X')) {
                $err->{class}         = 'msg_warn';
                $err->{err_type_err}  = 0;
                $err->{err_type_warn} = 1;
                $err->{err_type_info} = 0;
                $number_of_warnings += 1;
            }

            # TODO other classes for "X" etc? FIXME find all types of message.

            push @{$Errors}, $err;

            if (($File->{Opt}->{'Group Errors'}) and
                (($err->{type} eq 'E') or
                    ($err->{type} eq 'W') or
                    ($err->{type} eq 'X'))
                )
            {

                # index by num for errors and warnings only - info usually
                # gives context of error or warning
                if (!exists $Errors_bytype{$err->{num}}) {
                    $Errors_bytype{$err->{num}}->{instances} = [];
                    my $msg_text;
                    if ($err->{num} eq 'xmlwf') {

                        # FIXME need a catalog of errors from XML::LibXML
                        $msg_text = "XML Parsing Error";
                    }
                    elsif ($err->{num} eq 'html5') {
                        $msg_text = "HTML5 Validator Error";
                    }
                    else {
                        $msg_text = $RSRC{msg}->{$err->{num}}->{original};
                        $msg_text =~ s/%1/X/;
                        $msg_text =~ s/%2/Y/;
                    }
                    $Errors_bytype{$err->{num}}->{expl}        = $err->{expl};
                    $Errors_bytype{$err->{num}}->{generic_msg} = $msg_text;
                    $Errors_bytype{$err->{num}}->{msg}         = $err->{msg};
                    $Errors_bytype{$err->{num}}->{type}        = $err->{type};
                    $Errors_bytype{$err->{num}}->{class}       = $err->{class};
                    $Errors_bytype{$err->{num}}->{err_type_err} =
                        $err->{err_type_err};
                    $Errors_bytype{$err->{num}}->{err_type_warn} =
                        $err->{err_type_warn};
                    $Errors_bytype{$err->{num}}->{err_type_info} =
                        $err->{err_type_info};
                }
                push @{$Errors_bytype{$err->{num}}->{instances}}, $err;
            }
        }
    }

    @$Errors = values(%Errors_bytype) if $File->{Opt}->{'Group Errors'};

    # we are not sorting errors by line, as it would break the position
    # of auxiliary messages such as "start tag was here". We'll have to live
    # with the fact that XML well-formedness errors are listed first, then
    # validation errors
    #else {
    #   sort error by lines
    #  @{$Errors} = sort {$a->{line} <=> $b->{line} } @{$Errors};
    #}
    return $number_of_errors, $number_of_warnings, $number_of_info, $Errors;
}

#
# Chop the source line into 3 pieces; the character at which the error
# was detected, and everything to the left and right of that position.
# That way we can add markup to the relevant char without breaking &ent().
# Expects 1-based column indexes.
sub mark_error ($$)
{
    my $line    = shift;
    my $col     = shift;
    my $linelen = length($line);

    # Coerce column into an index valid within the line.
    if ($col < 1) {
        $col = 1;
    }
    elsif ($col > $linelen) {
        $col = $linelen;
    }
    $col--;

    my $left = substr($line, 0,    $col);
    my $char = substr($line, $col, 1);
    my $right = substr($line, $col + 1);

    $char = &ent($char);
    $char =
        qq(<strong title="Position where error was detected.">$char</strong>);
    $line = &ent($left) . $char . &ent($right);

    return $line;
}

#
# Create a HTML representation of the document.
sub source
{
    my $File = shift;

    # Remove any BOM since we're not at BOT anymore...
    $File->{Content}->[0] = substr($File->{Content}->[0], 1)
        if ($File->{BOM} && scalar(@{$File->{Content}}));

    my @source = map({file_source_line => $_}, @{$File->{Content}});
    return \@source;
}

sub match_DTD_FPI_SI
{
    my ($File, $FPI, $SI) = @_;
    if ($CFG->{Types}->{$FPI}) {
        if ($CFG->{Types}->{$FPI}->{SysID}) {
            if ($SI ne $CFG->{Types}->{$FPI}->{SysID}) {
                
            }
        }
    }
    else {    # FPI not known, checking if the SI is
        while (my ($proper_FPI, $value) = each %{$CFG->{Types}}) {
            if ($value->{SysID} && $value->{SysID} eq $SI) {
                
            }
        }
    }
}

#
# Do an initial parse of the Document Entity to extract FPI.
sub preparse_doctype
{
    my $File = shift;

    #
    # Reset DOCTYPE, Root (for second invocation, probably not needed anymore).
    $File->{DOCTYPE} = '';
    $File->{Root}    = '';

    my $dtd = sub {
        return if $File->{Root};

        # TODO: The \s and \w are probably wrong now that the strings are
        # utf8_on
        my $declaration = shift;
        my $doctype_type;
        my $doctype_secondpart;
        
        if ($declaration =~
            /<!DOCTYPE\s+html(?:\s+SYSTEM\s+(['"])about:legacy-compat\1)?\s*>/si
            )
        {
            $File->{Root}    = "html";
            $File->{DOCTYPE} = "HTML5";
        }
        elsif ($declaration =~
            m(<!DOCTYPE\s+(\w[\w\.-]+)\s+(PUBLIC|SYSTEM)\s+(?:[\'\"])([^\"\']+)(?:[\"\'])(.*)>)si
            )
        {
            (   $File->{Root},    $doctype_type,
                $File->{DOCTYPE}, $doctype_secondpart
            ) = ($1, $2, $3, $4);
            if (($doctype_type eq "PUBLIC") and
                (($doctype_secondpart) =
                    $doctype_secondpart =~
                    m(\s+(?:[\'\"])([^\"\']+)(?:[\"\']).*)si)
                )
            {
                &match_DTD_FPI_SI($File, $File->{DOCTYPE},
                    $doctype_secondpart);
            }
        }
    };

    my $start = sub {
        my ($p, $tag, $attr) = @_;

        if ($File->{Root}) {
            return unless $tag eq $File->{Root};
        }
        else {
            $File->{Root} = $tag;
        }
        if ($attr->{xmlns}) {
            $File->{Namespace} = $attr->{xmlns};
        }
        if ($attr->{version}) {
            $File->{'Root Version'} = $attr->{version};
        }
        if ($attr->{baseProfile}) {
            $File->{'Root BaseProfile'} = $attr->{baseProfile};
        }

        # We're done parsing.
        $p->eof();
    };

    # we use HTML::Parser as pre-parser. May use html5lib or other in the future
    my $p = HTML::Parser->new(api_version => 3);

    # if content-type has shown we should pre-parse with XML mode, use that
    # otherwise (mostly text/html cases) use default mode
    $p->xml_mode(&is_xml($File));
    $p->handler(declaration => $dtd,   'text');
    $p->handler(start       => $start, 'self,tag,attr');

    my $line = 0;
    my $max  = scalar(@{$File->{Content}});
    $p->parse(
        sub {
            return ($line < $max) ? $File->{Content}->[$line++] . "\n" : undef;
        }
    );
    $p->eof();

    # TODO: These \s here are probably wrong now that the strings are utf8_on
    $File->{DOCTYPE} = '' unless defined $File->{DOCTYPE};
    $File->{DOCTYPE} =~ s(^\s+){ }g;
    $File->{DOCTYPE} =~ s(\s+$){ }g;
    $File->{DOCTYPE} =~ s(\s+) { }g;

    # Some document types actually need no doctype to be identified,
    # root element and some version attribute is enough
    # TODO applicable doctypes should be migrated to a config file?

    # if (($File->{DOCTYPE} eq '') and ($File->{Root} eq "svg") ) {
    #   if (($File->{'Root Version'}) or ($File->{'Root BaseProfile'}))
    #   {
    #     if (! $File->{'Root Version'}) { $File->{'Root Version'} = "0"; }
    #     if (! $File->{'Root BaseProfile'}) { $File->{'Root BaseProfile'} = "0"; }
    #     if ($File->{'Root Version'} eq "1.0"){
    #       $File->{DOCTYPE} = "-//W3C//DTD SVG 1.0//EN";
    #       $File->{"DOCTYPEless OK"} = TRUE;
    #       $File->{Opt}->{DOCTYPE} = "SVG 1.0";
    #     }
    #     if ((($File->{'Root Version'} eq "1.1") or ($File->{'Root Version'} eq "0")) and ($File->{'Root BaseProfile'} eq "tiny")) {
    #         $File->{DOCTYPE} = "-//W3C//DTD SVG 1.1 Tiny//EN";
    #         $File->{"DOCTYPEless OK"} = TRUE;
    #         $File->{Opt}->{DOCTYPE} = "SVG 1.1 Tiny";
    #     }
    #     elsif ((($File->{'Root Version'} eq "1.1")  or ($File->{'Root Version'} eq "0")) and ($File->{'Root BaseProfile'} eq "basic")) {
    #         $File->{DOCTYPE} = "-//W3C//DTD SVG 1.1 Basic//EN";
    #         $File->{Opt}->{DOCTYPE} = "SVG 1.1 Basic";
    #         $File->{"DOCTYPEless OK"} = TRUE;
    #     }
    #     elsif (($File->{'Root Version'} eq "1.1") and (!$File->{'Root BaseProfile'})) {
    #         $File->{DOCTYPE} = "-//W3C//DTD SVG 1.1//EN";
    #         $File->{Opt}->{DOCTYPE} = "SVG 1.1";
    #         $File->{"DOCTYPEless OK"} = TRUE;
    #     }
    #     if ($File->{'Root Version'} eq "0") { $File->{'Root Version'} = undef; }
    #     if ($File->{'Root BaseProfile'} eq "0") { $File->{'Root BaseProfile'} = undef; }
    #   }
    #   else {
    #     # by default for an svg root elt, we use SVG 1.1
    #     $File->{DOCTYPE} = "-//W3C//DTD SVG 1.1//EN";
    #     $File->{Opt}->{DOCTYPE} = "SVG 1.1";
    #     $File->{"DOCTYPEless OK"} = TRUE;
    #   }
    # }
    if (($File->{"DOCTYPEless OK"}) and ($File->{Opt}->{DOCTYPE})) {

        # doctypeless document type found, we fake the override
        # so that the parser will have something to validate against
        $File = &override_doctype($File);
    }
    return $File;
}

#
# Preprocess CGI parameters.
sub prepCGI
{
    my $File = shift;
    my $q    = shift;

    # The URL to this CGI script.
    $File->{Env}->{'Self URI'} = $q->url();

    my $param=$q->param();
        # Decode all other defined values as UTF-8.
        my @values = map { Encode::decode_utf8($_) } $q->param($param);
        $q->param($param, @values);

        # Skip parameters that should not be treated as booleans.
        next if $param =~ /^(?:accept(?:-(?:language|charset))?|ur[il])$/;

        

        # Parameters that are given to us without specifying a value get set
        # to a true value.
        $q->param($param, TRUE) unless $q->param($param);
    

    $File->{Env}->{'Home Page'} =
        URI->new_abs(".", $File->{Env}->{'Self URI'});

    # Use "url" unless a "uri" was also given.
    if ($q->param('url') and not $q->param('uri')) {
        $q->param('uri', $q->param('url'));
    }

    # Set output mode; needed in get_error_template if we end up there.
    $File->{Opt}->{Output} = $q->param('output') || 'html';

    # Issue a redirect for uri=referer.
    if ($q->param('uri') and $q->param('uri') eq 'referer') {
        if ($q->referer) {
            $q->param('uri', $q->referer);
            $q->param('accept', $q->http('Accept')) if ($q->http('Accept'));
            $q->param('accept-language', $q->http('Accept-Language'))
                if ($q->http('Accept-Language'));
            $q->param('accept-charset', $q->http('Accept-Charset'))
                if ($q->http('Accept-Charset'));
            print redirect(-uri => &self_url_q($q, $File), -vary => 'Referer');
            exit;
        }
        else {

            # No Referer header was found.
            $File->{'Error Flagged'} = TRUE;
            &get_error_template($File)->param(fatal_referer_error => TRUE);
        }
    }

    # Supersede URL with an uploaded fragment.
    if ($q->param('fragment')) {
        $q->param('uri', 'upload://Form Submission');
        $File->{'Direct Input'} = TRUE;    # Tag it for later use.
    }

    # Redirect to a GETable URL if method is POST without a file upload.
    if (defined $q->request_method and
        $q->request_method eq 'POST' and
        not($File->{'Is Upload'} or $File->{'Direct Input'}))
    {
        my $thispage = &self_url_q($q, $File);
        print redirect $thispage;
        exit;
    }

    #
    # Flag an error if we didn't get a file to validate.
    unless ($q->param('uri')) {
        $File->{'Error Flagged'} = TRUE;
        my $tmpl = &get_error_template($File);
        $tmpl->param(fatal_uri_error  => TRUE);
        $tmpl->param(fatal_uri_scheme => 'undefined');
    }

    return $q;
}

#
# Set parse mode (SGML or XML) based on a number of preparsed factors:
# * HTTP Content-Type
# * Doctype Declaration
# * XML Declaration
# * XML namespaces
sub set_parse_mode
{
    my $File = shift;
    my $CFG  = shift;
    my $fpi  = $File->{DOCTYPE};
    $File->{ModeChoice} = '';
    my $parseModeFromDoctype = $CFG->{Types}->{$fpi}->{'Parse Mode'} || 'TBD';

    my $xmlws = qr/[\x20\x09\x0D\x0A]/o;

    # $File->{Mode} may have been set in parse_content_type
    # and it would come from the Media Type
    my $parseModeFromMimeType = $File->{Mode};
    my $begincontent          = join "\x20",
        @{$File->{Content}};    # for the sake of xml decl detection,
                                # the 10 first lines should be safe
    my $parseModeFromXMLDecl = (
        $begincontent =~
            /^ ${xmlws}*                # whitespace before the decl should not be happening
                                        # but we are greedy for the sake of detection, not validation
      <\?xml ${xmlws}+                  # start matching an XML Declaration
      version ${xmlws}* =               # for documents, version info is mandatory
      ${xmlws}* (["'])1.[01]\1          # hardcoding the existing XML versions.
                                        # Maybe we should use \d\.\d
      (?:${xmlws}+ encoding
       ${xmlws}* = ${xmlws}*
       (["'])[A-Za-z][a-zA-Z0-9_-]+\2
      )?                                # encoding info is optional
      (?:${xmlws}+ standalone
       ${xmlws}* = ${xmlws}*
       (["'])(?:yes|no)\3
      )?                                # ditto standalone info, optional
      ${xmlws}* \?>                     # end of XML Declaration
    /ox
        ?
            'XML' :
            'TBD'
    );

    my $parseModeFromNamespace = 'TBD';
    # http://www.w3.org/Bugs/Public/show_bug.cgi?id=9967
    $parseModeFromNamespace = 'XML'
        if ($File->{Namespace} && $parseModeFromDoctype ne 'HTML5');

    if (($parseModeFromMimeType eq 'TBD') and
        ($parseModeFromXMLDecl   eq 'TBD') and
        ($parseModeFromNamespace eq 'TBD') and
        (!exists $CFG->{Types}->{$fpi}))
    {

        # if the mime type is text/html (ambiguous, hence TBD mode)
        # and the doctype isn't in the catalogue
        # and XML prolog detection was unsuccessful
        # and we found no namespace at the root
        # ... throw in a warning
       
        return;
    }

    $parseModeFromDoctype = 'TBD'
        unless $parseModeFromDoctype eq 'SGML' or
            $parseModeFromDoctype eq 'HTML5' or
            $parseModeFromDoctype eq 'XML'   or
            $parseModeFromNamespace eq 'XML';

    if (($parseModeFromDoctype eq 'TBD') and
        ($parseModeFromXMLDecl  eq 'TBD') and
        ($parseModeFromMimeType eq 'TBD') and
        ($parseModeFromNamespace eq 'TBD'))
    {

        # if all factors are useless to give us a parse mode
        # => we use SGML-based DTD validation as a default
        $File->{Mode}       = 'DTD+SGML';
        $File->{ModeChoice} = 'Fallback';

        # and send warning about the fallback
        
        return;
    }

    if ($parseModeFromMimeType ne 'TBD') {

        # if The mime type gives clear indication of whether the document is
        # XML or not
        if (($parseModeFromDoctype ne 'TBD') and
            ($parseModeFromDoctype ne 'HTML5') and
            ($parseModeFromMimeType ne $parseModeFromDoctype))
        {

            # if document-type recommended mode and content-type recommended
            # mode clash, shoot a warning
            # unknown doctypes will not trigger this
            # neither will html5 documents, which can be XML or not
            
        }

        # mime type has precedence, we stick to it
        $File->{ModeChoice} = 'Mime';
        if ($parseModeFromDoctype eq "HTML5") {
            $File->{Mode} = 'HTML5+' . $File->{Mode};
        }
        else {
            $File->{Mode} = 'DTD+' . $File->{Mode};
        }
        return;
    }

    if ($parseModeFromDoctype ne 'TBD') {

        # the mime type is ambiguous (hence we didn't stop at the previous test)
        # but by now we're sure that the document type is a good indication
        # so we use that.
        if ($parseModeFromDoctype eq "HTML5") {
            if ($parseModeFromXMLDecl eq "XML" or
                $parseModeFromNamespace eq "XML")
            {
                $File->{Mode} = "HTML5+XML";
            }
            else {
                $File->{Mode} = "HTML5";
            }
        }
        else {    # not HTML5
            $File->{Mode} = "DTD+" . $parseModeFromDoctype;
        }
        $File->{ModeChoice} = 'Doctype';
        return;
    }

    if ($parseModeFromXMLDecl ne 'TBD') {

        # the mime type is ambiguous (hence we didn't stop at the previous test)
        # and so was the doctype
        # but we found an XML declaration so we use that.
        if ($File->{Mode} eq "") {
            $File->{Mode} = "DTD+" . $parseModeFromXMLDecl;
        }
        elsif ((my $ix = index($File->{Mode}, '+')) != -1) {
            substr($File->{Mode}, $ix + 1) = $parseModeFromXMLDecl;
        }
        else {
            $File->{Mode} = $File->{Mode} . "+" . $parseModeFromXMLDecl;
        }
        $File->{ModeChoice} = 'XMLDecl';
        return;
    }

    # this is the last case. We know that all  modes are not TBD,
    # yet mime type, doctype AND XML DECL tests have failed => we are saved
    # by the presence of namespaces
    if ($File->{Mode} eq "") {
        $File->{Mode} = "DTD+" . $parseModeFromNamespace;
    }
    elsif ((my $ix = index($File->{Mode}, '+')) != -1) {
        substr($File->{Mode}, $ix + 1) = $parseModeFromNamespace;
    }
    else {
        $File->{Mode} = $File->{Mode} . "+" . $parseModeFromNamespace;
    }
    $File->{ModeChoice} = 'Namespace';
}

#
# Utility sub to tell if mode "is" XML.
sub is_xml
{
    index(shift->{Mode}, 'XML') != -1;
}

#
# Check charset conflicts and add any warnings necessary.
sub charset_conflicts
{
    my $File = shift;

    #
    # Handle the case where there was no charset to be found.
    unless ($File->{Charset}->{Use}) {
        
        $File->{Tentative} |= T_WARN;
    }

    #
    # Add a warning if there was charset info conflict (HTTP header,
    # XML declaration, or <meta> element).
    # filtering out some of the warnings in direct input mode where HTTP
    # encoding is a "fake"
    if ((   charset_not_equal(
                $File->{Charset}->{HTTP},
                $File->{Charset}->{XML}
            )
        ) and
        not($File->{'Direct Input'})
        )
    {
        
    }
    elsif (
        charset_not_equal($File->{Charset}->{HTTP}, $File->{Charset}->{META})
        and
        not($File->{'Direct Input'}))
    {
        
    }
    elsif (
        charset_not_equal($File->{Charset}->{XML}, $File->{Charset}->{META}))
    {
       
        $File->{Tentative} |= T_WARN;
    }

    return $File;
}

#
# Transcode to UTF-8
sub transcode
{
    my $File = shift;

    my $general_charset = $File->{Charset}->{Use};
    my $exact_charset   = $general_charset;

    # TODO: This should be done before transcode()
    if ($general_charset eq 'utf-16') {
        if ($File->{Charset}->{Auto} =~ m/^utf-16[bl]e$/) {
            $exact_charset = $File->{Charset}->{Auto};
        }
        else { $exact_charset = 'utf-16be'; }
    }

    my $cs = $exact_charset;

    if ($CFG->{Charsets}->{$cs}) {
        if (index($CFG->{Charsets}->{$cs}, 'ERR ') != -1) {

            # The encoding is not supported due to policy

            $File->{'Error Flagged'} = TRUE;
            my $tmpl = &get_error_template($File);
            $tmpl->param(fatal_transcode_error   => TRUE);
            $tmpl->param(fatal_transcode_charset => $cs);

            # @@FIXME might need better text
            $tmpl->param(fatal_transcode_errmsg =>
                    'This encoding is not supported by the validator.');
            return $File;
        }
        elsif (index($CFG->{Charsets}->{$cs}, 'X ') != -1) {

            # possibly problematic, we recommend another alias
            my $recommended_charset = $CFG->{Charsets}->{$cs};
            $recommended_charset =~ s/X //;
         
        }
    }

    # Does the system support decoding this encoding?
    my $enc = Encode::find_encoding($cs);

    if (!$enc) {

        # This system's Encode installation does not support
        # the character encoding; might need additional modules

        $File->{'Error Flagged'} = TRUE;
        my $tmpl = &get_error_template($File);
        $tmpl->param(fatal_transcode_error   => TRUE);
        $tmpl->param(fatal_transcode_charset => $cs);

        # @@FIXME might need better text
        $tmpl->param(fatal_transcode_errmsg => 'Encoding not supported.');
        return $File;
    }
    elsif (!$CFG->{Charsets}->{$cs}) {

        # not in the list, but technically OK -> we warn
       

    }

    my $output;
    my $input = $File->{Bytes};
    my $err      = {};

    # Try to transcode
    eval { $output = $enc->decode($input, Encode::FB_CROAK); };

    if ($@) {
    eval { $output = $enc->decode($input, Encode::FB_DEFAULT); };
    $err->{msg}='more then one encoding';
    $err->{num}=448;
    push @{$File->{Errors}}, $err;
    
    }
   
    #print @{$File->{Errors}}
    #$File->{Errors} = [$err];

    # @@FIXME is this what we want?
    $output =~ s/\015?\012/\n/g;

    # make sure we deal only with unix newlines
    # tentative fix for http://www.w3.org/Bugs/Public/show_bug.cgi?id=3992
    $output =~ s/(\r\n|\n|\r)/\n/g;

    #debug: we could check if the content has utf8 bit on with
    #$output= utf8::is_utf8($output) ? 1 : 0;
    $File->{Content} = [split /\n/, $output];

    return $File;
}

sub find_encodings
{
    my $File  = shift;
    my $bom   = HTML::Encoding::encoding_from_byte_order_mark($File->{Bytes});
    my @first = HTML::Encoding::encoding_from_first_chars($File->{Bytes});

    if (defined $bom) {

        # @@FIXME this BOM entry should not be needed at all!
        $File->{BOM} = length(Encode::encode($bom, "\x{FEFF}"));
        $File->{Charset}->{Auto} = lc $bom;
    }
    else {
        $File->{Charset}->{Auto} = lc($first[0]) if @first;
    }

    my $xml = HTML::Encoding::encoding_from_xml_document($File->{Bytes});
    $File->{Charset}->{XML} = lc $xml if defined $xml;

    my %metah;
    foreach my $try (@first) {

        # @@FIXME I think the old code used HTML::Parser xml mode, check if ok
        my $meta =
            HTML::Encoding::encoding_from_meta_element($File->{Bytes}, $try);
        $metah{lc($meta)}++ if defined $meta and length $meta;
    }

    if (!%metah) {

        # HTML::Encoding doesn't support HTML5 <meta charset> as of 0.60,
        # check it ourselves.  HTML::HeadParser >= 3.60 is required for this.

        my $hp           = HTML::HeadParser->new();
        my $seen_doctype = FALSE;
        my $is_html5     = FALSE;
        $hp->handler(
            declaration => sub {
                my ($tag, $text) = @_;
                return if ($seen_doctype || uc($tag) ne '!DOCTYPE');
                $seen_doctype = TRUE;
                $is_html5     = TRUE
                    if (
                    $text =~ /<!DOCTYPE\s+html
                                    (\s+SYSTEM\s+(['"])about:legacy-compat\2)?
                                    \s*>/six
                    );
            },
            'tag,text'
        );
        $hp->parse($File->{Bytes});
        if ($is_html5) {
            my $cs = $hp->header('X-Meta-Charset');
            $metah{lc($cs)}++ if (defined($cs) && length($cs));
        }
    }

    if (%metah) {
        my @meta = sort { $metah{$b} <=> $metah{$a} } keys %metah;
        $File->{Charset}->{META} = $meta[0];
    }

    return $File;
}

#
# Abort with a message if an error was flagged at point.
sub abort_if_error_flagged
{
    my $File = shift;

    return unless $File->{'Error Flagged'};
    return if $File->{'Error Handled'};    # Previous error, keep going.

    exit;
}

#
# conflicting encodings
sub charset_not_equal
{
    my $encodingA = shift;
    my $encodingB = shift;
    return $encodingA && $encodingB && ($encodingA ne $encodingB);
}

#
# Construct a self-referential URL from a CGI.pm $q object.
sub self_url_q
{
    my ($q, $File) = @_;
    my $thispage = $File->{Env}->{'Self URI'} . '?';

    # Pass-through parameters
    for my $param (qw(uri accept accept-language accept-charset)) {
        $thispage .= "$param=" . uri_escape($q->param($param)) . ';'
            if $q->param($param);
    }

    # Boolean parameters
    for my $param (qw(ss outline No200 verbose group)) {
        $thispage .= "$param=1;" if $q->param($param);
    }

    # Others
    if ($q->param('doctype') and $q->param('doctype') !~ /(?:Inline|detect)/i)
    {
        $thispage .= 'doctype=' . uri_escape($q->param('doctype')) . ';';
    }
    if ($q->param('charset') and $q->param('charset') !~ /detect/i) {
        $thispage .= 'charset=' . uri_escape($q->param('charset')) . ';';
    }

    $thispage =~ s/[\?;]$//;
    return $thispage;
}

#
# Construct a self-referential URL from a $File object.
sub self_url_file
{
    my $File = shift;

    my $thispage    = $File->{Env}->{'Self URI'};
    my $escaped_uri = uri_escape($File->{URI});
    $thispage .= qq(?uri=$escaped_uri);
    $thispage .= ';ss=1' if $File->{Opt}->{'Show Source'};
    $thispage .= ';st=1' if $File->{Opt}->{'Show Tidy'};
    $thispage .= ';outline=1' if $File->{Opt}->{Outline};
    $thispage .= ';No200=1' if $File->{Opt}->{No200};
    $thispage .= ';verbose=1' if $File->{Opt}->{Verbose};
    $thispage .= ';group=1' if $File->{Opt}->{'Group Errors'};
    $thispage .= ';accept=' . uri_escape($File->{Opt}->{'Accept Header'})
        if $File->{Opt}->{'Accept Header'};
    $thispage .=
        ';accept-language=' .
        uri_escape($File->{Opt}->{'Accept-Language Header'})
        if $File->{Opt}->{'Accept-Language Header'};
    $thispage .=
        ';accept-charset=' .
        uri_escape($File->{Opt}->{'Accept-Charset Header'})
        if $File->{Opt}->{'Accept-Charset Header'};

    return $thispage;
}

#####

package W3C::Validator::EventHandler;

#
# Define global constants
use constant TRUE  => 1;
use constant FALSE => 0;

#
# Tentative Validation Severities.
use constant T_WARN  => 4;    # 0000 0100
use constant T_ERROR => 8;    # 0000 1000

sub new
{
    my $class  = shift;
    my $parser = shift;
    my $File   = shift;
    my $CFG    = shift;
    my $self   = {_file => $File, CFG => $CFG, _parser => $parser};
    bless $self, $class;
}

sub start_element
{
    my ($self, $element) = @_;

    my $has_xmlns   = FALSE;
    my $xmlns_value = undef;

    # If in XML mode, find namespace used for each element.
    if ((my $attr = $element->{Attributes}->{xmlns}) &&
        &W3C::Validator::MarkupValidator::is_xml($self->{_file}))
    {
        $xmlns_value = "";

        # Try with SAX method
        if ($attr->{Value}) {
            $has_xmlns   = TRUE;
            $xmlns_value = $attr->{Value};
        }

        #next if $has_xmlns;

        # The following is not SAX, but OpenSP specific.
        my $defaulted = $attr->{Defaulted} || '';
        if ($defaulted eq "specified") {
            $has_xmlns = TRUE;
            $xmlns_value .=
                join("", map { $_->{Data} } @{$attr->{CdataChunks}});
        }
    }

    my $doctype = $self->{_file}->{DOCTYPE};

    if (!defined($self->{CFG}->{Types}->{$doctype}->{Name}) ||
        $element->{Name} ne $self->{CFG}->{Types}->{$doctype}->{Name})
    {

        # add to list of non-root namespaces
        push(@{$self->{_file}->{Namespaces}}, $xmlns_value) if $has_xmlns;
    }
    elsif (!$has_xmlns &&
        $self->{CFG}->{Types}->{$doctype}->{"Namespace Required"})
    {

        # whine if the root xmlns attribute is noted as required by spec,
        # but not present
        my $err      = {};
        my $location = $self->{_parser}->get_location();
        &W3C::Validator::MarkupValidator::set_error_uri($err,
            $location->{FileName});

        # S::P::O does not provide src context, set to empty for non-doc errors.
        $err->{src}  = "" if $err->{uri};
        $err->{line} = $location->{LineNumber};
        $err->{char} = $location->{ColumnNumber};
        $err->{num}  = "no-xmlns";
        $err->{type} = "E";
        $err->{msg} =
            "Missing xmlns attribute for element $element->{Name}. The " .
            "value should be: $self->{CFG}->{Types}->{$doctype}->{Namespace}";

        # ...
        $self->{_file}->{'Is Valid'} = FALSE;
        push @{$self->{_file}->{Errors}}, $err;
    }
    elsif ($has_xmlns and
        (defined $self->{CFG}->{Types}->{$doctype}->{Namespace}) and
        ($xmlns_value ne $self->{CFG}->{Types}->{$doctype}->{Namespace}))
    {

        # whine if root xmlns element is not the one specificed by the spec
        my $err      = {};
        my $location = $self->{_parser}->get_location();
        &W3C::Validator::MarkupValidator::set_error_uri($err,
            $location->{FileName});

        # S::P::O does not provide src context, set to empty for non-doc errors.
        $err->{line} = $location->{LineNumber};
        $err->{char} = $location->{ColumnNumber};
        $err->{num}  = "wrong-xmlns";
        $err->{type} = "E";
        $err->{msg} =
            "Wrong xmlns attribute for element $element->{Name}. The " .
            "value should be: $self->{CFG}->{Types}->{$doctype}->{Namespace}";

        # ...
        $self->{_file}->{'Is Valid'} = FALSE;
        push @{$self->{_file}->{Errors}}, $err;
    }
}

sub error
{
    my $self  = shift;
    my $error = shift;
    my $mess;
    eval { $mess = $self->{_parser}->split_message($error); };
    if ($@) {

        # this is a message that S:P:O could not handle, we skip its croaking
        return;
    }
    my $File = $self->{_file};

    my $err = {};
    &W3C::Validator::MarkupValidator::set_error_uri($err,
        $self->{_parser}->get_location()->{FileName});

    # S::P::O does not provide src context, set to empty for non-doc errors.
    $err->{src}  = "" if $err->{uri};
    $err->{line} = $mess->{primary_message}{LineNumber};
    $err->{char} = $mess->{primary_message}{ColumnNumber} + 1;
    $err->{num}  = $mess->{primary_message}{Number};
    $err->{type} = $mess->{primary_message}{Severity};
    $err->{msg}  = $mess->{primary_message}{Text};

    # our parser OpenSP is not quite XML-aware, or XML Namespaces Aware,
    # so we filter out a few errors for now

    my $is_xml = &W3C::Validator::MarkupValidator::is_xml($File);

    if ($is_xml and $err->{num} eq '108' and $err->{msg} =~ m{ "xmlns:\S+"}) {

        # the error is about a missing xmlns: attribute definition"
        return;    # this is not an error, 'cause we said so
    }

    if ($err->{num} eq '187')

        # filtering out no "document type declaration; will parse without
        # validation" if root element is not html and mode is xml...
    {

        # since parsing was done without validation, result can only be
        # "well-formed"
        if ($is_xml and lc($File->{Root}) ne 'html') {
            $File->{XMLWF_ONLY} = TRUE;
            
            return;    # don't report this as an error, just proceed
        }

        # if mode is not XML, we do report the error. It should not happen in
        # the case of <html> without doctype, in that case the error message
        # will be #344
    }

    if (($err->{num} eq '113') and index($err->{msg}, 'xml:space') != -1) {

        # FIXME
        # this is a problem with some of the "flattened" W3C DTDs, filtering
        # them out to not confuse users. hoping to get the DTDs fixed, see
        # http://lists.w3.org/Archives/Public/www-html-editor/2007AprJun/0010.html
        return;    # don't report this, just proceed
    }

    if ($is_xml and $err->{num} eq '344' and $File->{Namespace}) {

        # we are in XML mode, we have a namespace, but no doctype.
        # the validator will already have said "no doctype, falling back to
        # default" above
        # no need to report this.
        return;    # don't report this, just proceed
    }

    if (($err->{num} eq '248') or
        ($err->{num} eq '247') or
        ($err->{num} eq '246'))
    {

        # these two errors should be triggered by -wmin-tag to report shorttag
        # used, but we're making them warnings, not errors
        # see http://www.w3.org/TR/html4/appendix/notes.html#h-B.3.7
        $err->{type} = "W";
    }

    # Workaround for onsgmls as of 1.5 sometimes allegedly reporting errors
    # beyond EOL.  If you see this warning in your web server logs, please
    # let the validator developers know, see http://validator.w3.org/feedback.html
    # As long as $err may be from somewhere else than the document (such as
    # from a DTD) and we have no way of identifying these cases, this
    # produces bogus results and error log spewage, so commented out for now.
    #  if ((my $l = length($File->{Content}->[$err->{line}-1])) < $err->{char}) {
    #    warn("Warning: reported error column larger than line length " .
    #         "($err->{char} > $l) in $File->{URI} line $err->{line}, " .
    #         "OpenSP bug? Resetting to line length.");
    #    $err->{char} = $l;
    #  }

    # No or unknown FPI and a relative SI.
    if ($err->{msg} =~ m(cannot (?:open|find))) {
        $File->{'Error Flagged'} = TRUE;
        my $tmpl = &W3C::Validator::MarkupValidator::get_error_template($File);
        $tmpl->param(fatal_parse_extid_error => TRUE);
        $tmpl->param(fatal_parse_extid_msg   => $err->{msg});
    }

    # No DOCTYPE found! We are falling back to vanilla DTD
    if (index($err->{msg}, "prolog can't be omitted") != -1) {
        if (lc($File->{Root}) eq 'html') {
            my $dtd = $File->{"Default DOCTYPE"}->{$is_xml ? "XHTML" : "HTML"};
            
        }
        else {    # not html root element, we are not using fallback
            unless ($is_xml) {
                $File->{'Is Valid'} = FALSE;
                
            }
        }

        return;    # Don't report this as a normal error.
    }

    # TODO: calling exit() here is probably a bad idea
    W3C::Validator::MarkupValidator::abort_if_error_flagged($File);

    push @{$File->{Errors}}, $err;

    # ...
    $File->{'Is Valid'} = FALSE if $err->{type} eq 'E';

    if (defined $mess->{aux_message}) {

        # "duplicate id ... first defined here" style messages
        push @{$File->{Errors}},
            {
            line => $mess->{aux_message}{LineNumber},
            char => $mess->{aux_message}{ColumnNumber} + 1,
            msg  => $mess->{aux_message}{Text},
            type => 'I',
            };
    }
}

package W3C::Validator::EventHandler::Outliner;

#
# Define global constants
use constant TRUE  => 1;
use constant FALSE => 0;

#
# Tentative Validation Severities.
use constant T_WARN  => 4;    # 0000 0100
use constant T_ERROR => 8;    # 0000 1000

use base qw(W3C::Validator::EventHandler);

sub new
{
    my $class  = shift;
    my $parser = shift;
    my $File   = shift;
    my $CFG    = shift;
    my $self   = $class->SUPER::new($parser, $File, $CFG);
    $self->{am_in_heading} = 0;
    $self->{heading_text}  = [];
    bless $self, $class;
}

sub data
{
    my ($self, $chars) = @_;
    push(@{$self->{heading_text}}, $chars->{Data}) if $self->{am_in_heading};
}

sub start_element
{
    my ($self, $element) = @_;
    if ($element->{Name} =~ /^h([1-6])$/i) {
        $self->{_file}->{heading_outline} ||= "";
        $self->{_file}->{heading_outline} .=
            "    " x int($1) . "[$element->{Name}] ";
        $self->{am_in_heading} = 1;
    }

    return $self->SUPER::start_element($element);
}

sub end_element
{
    my ($self, $element) = @_;
    if ($element->{Name} =~ /^h[1-6]$/i) {
        my $text = join("", @{$self->{heading_text}});
        $text =~ s/^\s+//g;
        $text =~ s/\s+/ /g;
        $text =~ s/\s+$//g;
        $self->{_file}->{heading_outline} .= "$text\n";
        $self->{am_in_heading} = 0;
        $self->{heading_text}  = [];
    }
}

#####

package W3C::Validator::UserAgent;

use HTTP::Message qw();
use LWP::UserAgent 2.032 qw();    # Need 2.032 for default_header()
use Net::hostent qw(gethostbyname);
use Net::IP qw();
use Socket qw(inet_ntoa);

use base qw(LWP::UserAgent);

BEGIN {

    # The 4k default line length in LWP <= 5.832 isn't enough for example to
    # accommodate 4kB cookies (RFC 2985); bump it (#6678).
    require LWP::Protocol::http;
    push(@LWP::Protocol::http::EXTRA_SOCK_OPTS, MaxLineLength => 8 * 1024);
}

sub new
{
    my ($proto, $CFG, $File, @rest) = @_;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@rest);

    $self->{'W3C::Validator::CFG'}  = $CFG;
    $self->{'W3C::Validator::File'} = $File;

    $self->env_proxy();
    $self->agent($File->{Opt}->{'User Agent'});
    $self->protocols_allowed($CFG->{Protocols}->{Allow} || ['http', 'https']);

    # Don't parse the http-equiv stuff.
    $self->parse_head(0);

    # Tell caches in the middle we want a fresh copy (Bug 4998).
    $self->default_header('Cache-Control' => 'max-age=0');

    # If not in debug mode, set Accept-Encoding to what LWP (>= 5.816) can handle
    $self->default_header(
        'Accept-Encoding' => scalar HTTP::Message::decodable())
        if (!$File->{Opt}->{Debug} && HTTP::Message->can('decodable'));

    # Our timeout should be set to something lower than the web server's,
    # remembering to give some head room for the actual validation to take
    # place after the document has been fetched (something like 15 seconds
    # should be plenty).  validator.w3.org instances have their timeout set
    # to 60 seconds as of writing this (#4985, #6950).
    $self->timeout(45);

    return $self;
}

sub redirect_ok
{
    my ($self, $req, $res) = @_;
    return $self->SUPER::redirect_ok($req, $res) && $self->uri_ok($req->uri());
}

sub uri_ok
{
    my ($self, $uri) = @_;

    return 1
        if ($self->{'W3C::Validator::CFG'}->{'Allow Private IPs'} ||
        !$uri->can('host'));

    my $h5uri = $self->{'W3C::Validator::CFG'}->{External}->{HTML5};
    if ($h5uri) {
        my $clone = $uri->clone();
        $clone->query(undef);
        $clone->fragment(undef);
        $h5uri = URI->new($h5uri);
        $h5uri->query(undef);
        $h5uri->fragment(undef);
        return 1 if $clone->eq($h5uri);
    }

    my $addr = my $iptype = undef;
    if (my $host = gethostbyname($uri->host())) {
        $addr = inet_ntoa($host->addr()) if $host->addr();
        if ($addr && (my $ip = Net::IP->new($addr))) {
            $iptype = $ip->iptype();
        }
    }
    if ($iptype && $iptype ne 'PUBLIC') {
        my $File = $self->{'W3C::Validator::File'};
        $File->{'Error Flagged'} = 1;
        my $tmpl = &W3C::Validator::MarkupValidator::get_error_template($File);
        $tmpl->param(fatal_ip_error    => 1);
        $tmpl->param(fatal_ip_host     => $uri->host() || 'undefined');
        $tmpl->param(fatal_ip_hostname => 1)
            if ($addr and $uri->host() ne $addr);
        return 0;
    }
    return 1;
}

# Local Variables:
# mode: perl
# indent-tabs-mode: nil
# cperl-indent-level: 4
# cperl-continued-statement-offset: 4
# cperl-brace-offset: -4
# perl-indent-level: 4
# End:
# ex: ts=4 sw=4 et
