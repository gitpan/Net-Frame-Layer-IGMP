#
# $Id: v3Report.pm 49 2009-05-31 13:15:34Z VinsWorldcom $
#
package Net::Frame::Layer::IGMP::v3Report;
use strict; use warnings;

use Net::Frame::Layer qw(:consts :subs);
use Exporter;
our @ISA = qw(Net::Frame::Layer Exporter);

our %EXPORT_TAGS = (
   consts => [qw(
      NF_IGMP_REPORTv3TYPE_MODEINCLUDE
      NF_IGMP_REPORTv3TYPE_MODEEXCLUDE
      NF_IGMP_REPORTv3TYPE_CHANGEINCLUDE
      NF_IGMP_REPORTv3TYPE_CHANGEEXCLUDE
      NF_IGMP_REPORTv3TYPE_ALLOWNEW
      NF_IGMP_REPORTv3TYPE_BLOCKOLD
   )],
);
our @EXPORT_OK = (
   @{$EXPORT_TAGS{consts}},
);

use constant NF_IGMP_REPORTv3TYPE_MODEINCLUDE   => 1;
use constant NF_IGMP_REPORTv3TYPE_MODEEXCLUDE   => 2;
use constant NF_IGMP_REPORTv3TYPE_CHANGEINCLUDE => 3;
use constant NF_IGMP_REPORTv3TYPE_CHANGEEXCLUDE => 4;
use constant NF_IGMP_REPORTv3TYPE_ALLOWNEW      => 5;
use constant NF_IGMP_REPORTv3TYPE_BLOCKOLD      => 6;

our @AS = qw(
   type
   auxDataLen
   numSources
   multicastAddress
   auxData
);
our @AA = qw(
   sourceAddress
);
__PACKAGE__->cgBuildIndices;
__PACKAGE__->cgBuildAccessorsScalar(\@AS);
__PACKAGE__->cgBuildAccessorsArray(\@AA);

#no strict 'vars';

sub new {
   shift->SUPER::new(
      type             => NF_IGMP_REPORTv3TYPE_MODEINCLUDE,
      auxDataLen       => 0,
      numSources       => 0,
      multicastAddress => '0.0.0.0',
      sourceAddress    => [],
      auxData          => "\0",
      @_,
   );
}

sub getLength {
   my $self = shift;
   my $len = 8 + length($self->auxData);
   $len += 4 for $self->sourceAddress;
   return $len;
}

sub pack {
   my $self = shift;

   # Calculate auxDataLen if auxData and auxDataLen = 0
   if (($self->auxData ne "\0") && ($self->auxDataLen == 0)) {
      # auxDataLen is number of 32-bit words
      if (my $mod = (length($self->auxData) * 8) % 32) {
          my $pad = (32 - $mod)/8;
          my $auxData = $self->auxData;
          # Add padding if required to make 32-bit flush
          $auxData .= "\0"x$pad;
          $self->auxData($auxData)
      }
      $self->auxDataLen(length($self->auxData)/4)
   }

   # Calculate numSources from sourceAddress array items
   if (scalar($self->sourceAddress) && ($self->numSources == 0)) {
      $self->numSources(scalar($self->sourceAddress))
   }

   my $raw = $self->SUPER::pack('CCna4',
      $self->type,
      $self->auxDataLen,
      $self->numSources,
      inetAton($self->multicastAddress),
   ) or return;

   for ($self->sourceAddress) {
      $raw .= inetAton($_);
   }

   if ($self->auxData ne "\0") {
      $raw .= $self->SUPER::pack('a*',
         $self->auxData,
      ) or return;
   }

   return $self->raw($raw);
}

sub unpack {
   my $self = shift;

   my ($type, $auxDataLen, $numSources, $multicastAddress, $payload) =
      $self->SUPER::unpack('CCna4 a*', $self->raw)
         or return;

   $self->type($type);
   $self->auxDataLen($auxDataLen);
   $self->numSources($numSources);
   $self->multicastAddress(inetNtoa($multicastAddress));

   my @sourceAddress = ();
   for my $num (0..$numSources-1) {
      if (defined($payload) && (length($payload) >= 4)) {
         my $addr = unpack 'a4', $payload;
         push @sourceAddress, inetNtoa($addr);
         $payload = substr $payload, 4;
      }
   }
   $self->sourceAddress(\@sourceAddress);
   $self->auxData("\0");

   # auxDataLen is length in 32-bit words so extra math (/4, *4)
   if (($self->auxDataLen > 0) && defined($payload) && ((length($payload)/4) >= $self->auxDataLen)) {
      my $auxData = substr $payload, 0, $self->auxDataLen*4;
      $self->auxData($auxData);
      $payload = substr $payload, $self->auxDataLen*4
   }

   $self->payload($payload);

   return $self;
}

sub encapsulate {
   my $self = shift;

   return $self->nextLayer if $self->nextLayer;

   if ($self->payload) {
      return 'IGMP::v3Report';
   }

   NF_LAYER_NONE;
}

sub print {
   my $self = shift;

   my $l = $self->layer;
   my $buf = sprintf
      "$l: type:%d  auxDataLen:%d  numSources:%d\n".
      "$l: multicastAddress:%s",
         $self->type, $self->auxDataLen, $self->numSources,
         $self->multicastAddress;

   for ($self->sourceAddress) {
      $buf .= sprintf
      "\n$l: sourceAddress:%s",
         $_
   }

   if ($self->auxData ne "\0") {
      $buf .= sprintf
      "\n$l: auxData:%s",
         $self->auxData
   }

   return $buf;
}

1;

__END__

=head1 NAME

Net::Frame::Layer::IGMP::v3Report - IGMP version 3 Report Message

=head1 SYNOPSIS

   use Net::Frame::Simple;
   use Net::Frame::Layer::IGMP qw(:consts);

   my $layer = Net::Frame::Layer::IGMP::v3Report->new(
      type             => NF_IGMP_REPORTv3TYPE_MODEINCLUDE,      auxDataLen       => 0,
      numSources       => 0,
      multicastAddress => '0.0.0.0',
      sourceAddress    => [],
      auxData          => undef,
   );

   #
   # Read a raw layer
   #

   my $layer = Net::Frame::Layer::IGMP::v3Report->new(raw => $raw);

   print $layer->print."\n";
   print 'PAYLOAD: '.unpack('H*', $layer->payload)."\n"
      if $layer->payload;

=head1 DESCRIPTION

This modules implements the encoding and decoding of the IGMP version 3 Report message.

RFC: ftp://ftp.rfc-editor.org/in-notes/rfc3376.txt

See also B<Net::Frame::Layer> for other attributes and methods.

=head1 ATTRIBUTES

=over 4

=item B<type>

Record type.

=item B<auxDataLen>

Length of the Auxiliary Data field in units of 32-bit words.

=item B<numSources>

Number of sources present in report.

=item B<multicastAddress>

Multicast address to which this report pertains.

=item B<sourceAddress>

Array of B<numSources> IP unicast addresses.

=item B<auxData>

Additional information.

=back

The following are inherited attributes. See B<Net::Frame::Layer> for more information.

=over 4

=item B<raw>

=item B<payload>

=item B<nextLayer>

=back

=head1 METHODS

=over 4

=item B<new>

=item B<new> (hash)

Object constructor. You can pass attributes that will overwrite default ones. See B<SYNOPSIS> for default values.

=back

The following are inherited methods. Some of them may be overriden in this layer, and some others may not be meaningful in this layer. See B<Net::Frame::Layer> for more information.

=over 4

=item B<layer>

=item B<computeLengths>

=item B<pack>

=item B<unpack>

=item B<encapsulate>

=item B<getLength>

=item B<getPayloadLength>

=item B<print>

=item B<dump>

=back

=head1 CONSTANTS

Load them: use Net::Frame::Layer::IGMP qw(:consts);

=over 4

=item B<NF_IGMP_REPORTv3TYPE_MODEINCLUDE>

=item B<NF_IGMP_REPORTv3TYPE_MODEEXCLUDE>

=item B<NF_IGMP_REPORTv3TYPE_CHANGEINCLUDE>

=item B<NF_IGMP_REPORTv3TYPE_CHANGEEXCLUDE>

=item B<NF_IGMP_REPORTv3TYPE_ALLOWNEW>

=item B<NF_IGMP_REPORTv3TYPE_BLOCKOLD>

IGMP version 3 Report message types.

=back

=head1 SEE ALSO

L<Net::Frame::Layer>

=head1 AUTHOR

Michael Vincent

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2013, Michael Vincent

You may distribute this module under the terms of the Artistic license.
See LICENSE.Artistic file in the source distribution archive.

=cut
