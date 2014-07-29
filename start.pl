#!/usr/bin/env perl

# use v5.20.0;


use utf8;
use strict;
use warnings;
use lib 'lib';
use open ':std', ':encoding(UTF-8)';
use feature qw/say switch unicode_strings/;

our $VERSION = 0.1;

use Coro;
use URI::Simple;
use File::Slurp;
use Coro::Select;
use Getopt::Args;
use LWP::UserAgent;
use LWP::Protocol::socks;
use List::Util 'max';
use List::MoreUtils 'uniq';
use Tor::ControlProtocol::ChangeIp;

arg url => (
    isa      => 'Str',
    required => 1,
    comment  => 'Target url, like this http://site.com/forum/',
);

opt help => (
	isa     => 'Bool',
	alias   => 'h',
	default => 0,
	comment => 'Show help message',
);

opt tor => (
	isa     => 'Bool',
	alias   => 'tr',
	default => 0,
	comment => 'Use TOR (default off)',
);

opt torServer => (
	isa     => 'Str',
	alias   => 'ts',
	default => 'socks://localhost:9050',
	comment => 'Tor socks5 server [socks|socks4|http|https] (default socks://localhost:9050)',
);

opt torPassword => (
	isa     => 'Str',
	alias   => 'tp',
	default => undef,
	comment => 'Tor control protocol password',
);

opt threads => (
	isa     => 'Int',
	alias   => 't',
	default => 10,
	comment => 'Number of asynchronous requests (default 10)',
);

opt reqLimit => (
	isa     => 'Int',
	alias   => 'rl',
	default => 10,
	comment => 'The number of requests from one ip (default 10)',
);

opt output => (
	isa     => 'Str',
	alias   => 'O',
	default => 'logins.txt',
	comment => 'File to save logins (default logins.txt)',
);

my $opts = optargs;

# Show help
die usage() if ($opts->{help});

my @useragents = read_file('data/user-agents.txt');
chomp(@useragents);

# Get pages list
our $maxResultsOnPage = 0;
our @pages = pagesList(getPagesCount());

sub pagesList {
	my ($totalUsersCount, $usersOnPageCount) = @_;

	my @result;
	my $tmp = 0;
	for (1..(($totalUsersCount/$usersOnPageCount)+1)) {
		push @result, $tmp;
		$tmp += $usersOnPageCount;
	}

	return @result;
}

sub getPagesCount {
	my $ua = LWP::UserAgent->new(agen => 'Mozilla/5.0 (X11; Linux i686; rv:25.0) Gecko/20100101 Firefox/25.0');

	say 'Get last page ...';
	$opts->{url} .= ($opts->{url} =~ m#/$#?'members/':'/members/');
	my $resp = $ua->get($opts->{url});
	die "Can't connect to server! ".$resp->status_line unless ($resp->is_success);

	my @usersCount = $resp->content =~ m#st=(\d+)#g;
	my $totalUsersCount = max(uniq(@usersCount));

	my @usersOnPage = $resp->content =~ m#max_results=(\d+)#g;
	my $usersOnPageCount = max(uniq(@usersOnPage));

	say 'Total users count ['.$totalUsersCount.']';
	say 'Users count on page ['.$usersOnPageCount.']'; $maxResultsOnPage = $usersOnPageCount;
	say 'Total make requests ['.(($totalUsersCount/$usersOnPageCount)+1).']';

	return ($totalUsersCount, $usersOnPageCount);
}


# Connect to tor control
my $tor;
if ($opts->{tor}) {
	$tor = Tor::ControlProtocol::ChangeIp->new;

	if ($opts->{torPassword}) {
		if ($tor->auth($opts->{torPassword})) {
			say 'TOR Auth [OK]';
		} else {
			say 'TOR Auth [ERROR]';
			exit;
		}
	} else {
		if ($tor->auth) {
			say 'TOR Auth [OK]';
		} else {
			say 'TOR Auth [ERROR]';
			exit;
		}
	}
}


my @coros;
my $requests = 0;
my $BadConnects = 0;

for (1..$opts->{threads}) {
	push @coros, async {
		my $ua = LWP::UserAgent->new( agent => $useragents[rand(@useragents)] );
		$ua->proxy(['http', 'https', 'ftp'] => $opts->{torServer}) if ($opts->{tor});

		while (@pages) {
			my $page = shift(@pages);
			# next unless ($page);

			if (defined $tor and $requests >= $opts->{reqLimit}) {
				$tor->ChangeIp;
				$requests=0;
				say 'Chang IP ...';
				$ua->agent($useragents[rand(@useragents)]);
			}

			REDO:
			my $targetURL = $opts->{url}.'?sort_key=members_display_name&sort_order=asc&max_results='.$maxResultsOnPage.'&st='.$page;
			my $resp = $ua->get($targetURL);
			unless ($resp->is_success) {
				warn "Can't connect to server! ".$resp->status_line;
				if ($BadConnects > 10) {
					say 'Sleep 30 seconds ...';
					sleep(30);
					$BadConnects=0;
					goto REDO;
				}

				$tor->ChangeIp; $requests=0;
				say 'Chang IP ...';
				$ua->agent($useragents[rand(@useragents)]);
				$BadConnects++;
				goto REDO;
			}

			$requests++;
			# say 'Request sended['.$requests.']';
			my @users = uniq($resp->content =~ m#<a\s+href=['|"].+?/user/\d+\-.+?/['|"]\s+title=['|"].+?['|"]\s{0,}>([^<]+)</a>#g);
			say 'Parsed Page['.$targetURL.'] Users['.scalar(@users).']';
			append_file( $opts->{output}, join("\n", @users)."\n" ) if (scalar(@users) > 0);
		}
	};
}

$_->join for (@coros);