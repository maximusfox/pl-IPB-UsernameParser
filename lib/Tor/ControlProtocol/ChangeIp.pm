package Tor::ControlProtocol::ChangeIp;

# Packages
use Carp;
use strict;
use warnings;

use IO::Socket;
use IO::Socket::INET;

sub new {
	my ($self, %args) = @_;
	$self = bless(\%args, $self);
	
	$self->{host} = ($self->{host}||'127.0.0.1');
	$self->{port} = ($self->{port}||9051);

	return $self;
}

sub connect {
	my ($self) = @_;

	$self->{socket} = IO::Socket::INET->new($self->{host}.':'.$self->{port});

	return 1 if ($self->{socket});
	return 0;
}

sub auth {
	my ($self, $password) = @_;

	$self->connect unless ($self->{socket});
	unless ($self->{socket}) {
		carp "Can't connect to ".$self->{host}.':'.$self->{port};
		return undef;
	}

	if ($password) {
		$self->{socket}->send('AUTHENTICATE "'.$password.'"'."\n");

		my $Respons = $self->_readFromNewLine();
		# print 'DBG: '.$Respons."\n";
		my ($code, $message) = $Respons =~ m#^(\d+)\s(.+)$#;

		return $message if ($code == 250);
		return undef;
	} else {
		$self->{socket}->send('AUTHENTICATE'."\n");

		my $Respons = $self->_readFromNewLine();
		# print 'DBG: '.$Respons."\n";
		my ($code, $message) = $Respons =~ m#^(\d+)\s(.+)$#;

		return $message if ($code == 250);
		return undef;
	}


}

sub ChangeIp {
	my ($self) = @_;

	return undef unless ($self->{socket});
	
	$self->{socket}->send('SETEVENTS SIGNAL'."\n");

	my $ResponsSetEventSignal = $self->_readFromNewLine();
	# print 'DBG 69 - '.$ResponsSetEventSignal."\n";

	my ($codeSetEventSignal, $messageSetEventSignal) = $ResponsSetEventSignal =~ m#^(\d+)\s(.+)$#;
	return 0 unless ($codeSetEventSignal == 250);

	$self->{socket}->send('SIGNAL NEWNYM'."\n");

	my $ResponsNEWNYM = $self->_readFromNewLine();
	# print 'DBG 78 - '.$ResponsNEWNYM."\n";

	my $ResponsSignalNEWNYM = $self->_readFromNewLine();
	# print 'DBG 82 - '.$ResponsSignalNEWNYM."\n";

	my ($codeNEWNYM, $messageNEWNYM) = $ResponsNEWNYM =~ m#^(\d+)\s(.+)$#;
	my ($codeSignalNEWNYM, $messageSignalNEWNYM) = $ResponsSignalNEWNYM =~ m#^(\d+)\s(.+)$#;
	return 0 unless ($codeNEWNYM == 250);
	return 0 unless ($codeSignalNEWNYM == 650);

	return 1;
}

sub _readFromNewLine {
	my ($self) = @_;

	my $buf;
	my $bufFull;

	while (1) {
		$self->{socket}->recv($buf, 1);
		last if (ord($buf) == 10);
		$bufFull .= $buf;
	}

	return $bufFull;
}

DESTROY {
	my ($self) = @_;
	$self->{socket}->send('quit'."\n");
}

1;