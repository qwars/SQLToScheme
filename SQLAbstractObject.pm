package SQLAbstractObject;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(to_statement to_object to_request);

use strict;
use warnings;

use Carp;
use SQL::Abstract::Tree;

sub new {
    my $class = shift;
    $class = ref $class || $class;
    my $self = {
        keys => {
            'copy'   => '=',
            'lt'     => '<',
            'gt'     => '>',
            'ltcopy' => '<=',
            'gtcopy' => '>=',
            'ltgt'   => '<>',
        },
        separator => '~',
        @_
    };
    $$self{template} = qq!["']*[$$self{separator}](\\w+)[$$self{separator}]["']*!
      unless exists $$self{template};
    $$self{template} = qr/$$self{template}/;
    $$self{unkeys}   = $$self{keys};
    $$self{keys}     = { reverse %{ $$self{unkeys} } };
    return bless $self, $class;
}

# ---------------------------------------------------------------

sub to_statement {
    my $sqlat = SQL::Abstract::Tree->new( { profile => 'console_monochrome' } );
    return $sqlat->unparse( $_[0]->assemble( $_[1] ) );
}

sub restore_key {
    my ( $self, $key ) = @_;
    $key = exists $$self{unkeys}{$key} ? $$self{unkeys}{$key} : $key;
    $key = uc $key;
    $key =~ s/_/ /g
      if $key !~
m/^(?:date|current|sec_to|time_to|unix|time|period|to|concat|octet|bit|substring|find_in|make|export|last_insert|inet|found|aes|des|release|get|is_free)_\w+$/i;

    return $key;
}

sub assemble {
    my $return;
    if ( ref $_[1] eq 'HASH' ) {

        # print Dumper [ keys %{ $_[1] } ];
        if ( scalar keys %{ $_[1] } > 1 ) {
            use Tie::IxHash;
            my $result = {};
            my $tie = tie( %{$result}, 'Tie::IxHash' );
            foreach (
                qw(< > != <> = <= >= between not exists like rlike or and as in asc desc select from join right_join left_join right_outer_join left_outer_join on where group_by having order_by limit offset procedure for_update lock_in_share_mode)
              )
            {
                $tie->Push( $_[0]->restore_key($_) => $_[0]->assemble( $_[1]{$_} ) )
                  if exists $_[1]{$_};
            }
            foreach ( keys %{$result} ) {
                $$result{$_} = [ '-LIST', $$result{$_} ]
                  if scalar @{ $$result{$_} } > 1 && ref $$result{$_}[0];
                push @{$return}, [ $_, [ $$result{$_} ] ];
            }
        }
        elsif ( my $key = ( keys %{ $_[1] } )[0] ) {
            my $restore = $_[0]->restore_key($key);
            my $assemble =
              defined $_[1]{$key} ? $_[0]->assemble( $_[1]{$key} ) : [ [ '-PAREN', [] ] ];

            $assemble = [ '-MISC', $assemble ]
              if defined $$assemble[1]
              && defined $$assemble[1][1]
              && $$assemble[1][1][0] =~ m/^then$/i;

            $assemble = [ [ '-PAREN', [ [ '-LIST', $assemble ] ] ] ]
              if $restore =~
m/^(?:if|ifnull|nullif|encode|decode|char|concat|format|benchmark|\w+_lock|strcmp|round|encrypt|instr|(add|sub)date|pow|week|truncate|lpad|rpad|left|right|replace|repeat|insert|elt|time_\w+|field|(find_in|make|export)_set|least|greatest|strcmp|match|substring|substring_\w+|concat_ws|concat|locate|conv|mod|coalesce|(aes|des)_(encrypt|decrypt)|date_\w+)$/i;

            $assemble = [ [ '-PAREN', [$assemble] ] ]
              if $restore =~
m/^(?:against|count|ascii|ord|bin|hex|oct|length|octet_length|md5|sha\d*|bit_length|avg|min|sum|variance|std(dev)*|bit_(or|and)|inet_(ntoa|aton)|unix_timestamp|sec_to_time|from_(unixtime|timestamp)|(l|r)*trim|soundex|space|encrypt|time_to_sec|sec_to_time|(old_)*password|reverse|(u|l)case|extract|quote|abs|sign|floor|ceiling|exp|degrees|radians|ln|year|yearweek|hour|minute|second|period_\w+|(from|to)_days|dayofweek|weekday|dayofmonth|dayofyear|month|dayname|monthname|quarter|log(\d*)|sqrt|(a)*(sin|tan(\d*)|cos)|rand)$/i;

            $assemble = [ [ '-LIST', $assemble ] ]
              if $restore =~ m/^(?:select)$/i
              && scalar @$assemble > 1
              && ref $$assemble[0]
              && $$assemble[0][0] !~ /match/i;

            $assemble = [ [ '-PAREN', $$assemble[0] ], $$assemble[1] ]
              if $restore =~ m/^(?:as)$/i && scalar @{ $$assemble[0] } > 2;

            $$assemble[1] = [ [ '-PAREN', [ [ '-LIST', $$assemble[1] ] ] ] ]
              if defined $$assemble[1] && $restore =~ m/(?:in)/i;

            return [ [ $restore, $assemble ] ] if $restore =~ m/^(?:as|mod|conv|concat_ws|concat)$/i;
            return [ $restore, $assemble ];
        }
    }
    elsif ( ref $_[1] eq 'ARRAY' ) {
        for ( my $i = 0 ; $i < @{ $_[1] } ; $i++ ) {
            push @{$return}, $_[0]->assemble( $_[1][$i] );
        }
        $$return[0] = [ '-MISC', [ shift @{$return}, shift @{$return} ] ]
          if defined $$return[0][1] && $$return[0][1][0] =~ m/^sql_/i;
        $return = [ [ '-MISC', $return ] ]
          if defined $$return[0][1] && $$return[0][1][0] =~ m/^case|extract/i;

    }
    elsif ( ref $_[1] eq 'SCALAR' ) {
        $return = [ '-LITERAL', [ ${ $_[1] } ] ];
    }
    else {
        $return = [ '-LITERAL', [ $_[1] ] ];
    }
    return $return;
}

# ---------------------------------------------------------------
sub to_object {
    my $sqlat = SQL::Abstract::Tree->new( { profile => 'console_monochrome' } );
    return $_[0]->disassemble( $sqlat->parse( $_[1] || $_[0]{sql_source} ) );
}

sub create_key {
    my ( $self, $key ) = @_;
    $key =~ s/\s+/_/g;
    $key = lc $key;
    return exists $$self{keys}{$key} ? $$self{keys}{$key} : $key;
}

sub _object {
    my ( $self, $source ) = @_;
    my $result;
    if ( $$source[0] =~ m/-literal/i ) {
        $result = $$source[1]->[0];
    }
    elsif ( $$source[0] =~ m/-paren/i ) {
        $result = $self->disassemble( $$source[1] );
    }
    elsif ( $$source[0] =~ m/-list/i ) {
        foreach ( @{ $$source[1] } ) {
            push @$result, $self->disassemble($_);
        }
    }
    elsif ( $$source[0] =~ m/-misc/i ) {
        foreach ( @{ $$source[1] } ) {
            push @$result, $self->disassemble($_);
        }
    }
    else {
        $source = [ map { @{$_} } @$source ] if ref $$source[0];
        $result = { @{$source} };
        foreach ( keys %{$result} ) {
            unless ( $#{ $$result{$_} } ) {
                $$result{$_} = $self->disassemble( $$result{$_}[0] );
            }
            elsif ( ref $$result{$_}[0] ) {
                for ( my $i = 0 ; $i < scalar @{ $$result{$_} } ; $i++ ) {
                    $$result{$_}[$i] = $self->disassemble( $$result{$_}[$i] );
                }
            }
            else {
                $$result{$_} = $self->disassemble( $$result{$_} );
            }
            $$result{ $self->create_key($_) } = delete $$result{$_};
        }
    }
    return $result;
}

sub disassemble {
    my $self = shift;
    return $_[0] unless ref $_[0];
    my @source = @{ $_[0] };
    my $result;
    if ( $#source > 1 ) {
        foreach my $source (@source) {
            $$result{ $self->create_key( $$source[0] ) } = $self->disassemble( $$source[1] );
        }
    }
    elsif ( $#source == 1 ) {
        $result = $self->_object( \@source );
    }
    else {
        $result = $self->disassemble( $source[0] )

    }
    return $result;
}

# ---------------------------------------------------------------

sub to_request {
    my ( $self, $object, $param ) = @_;
    my $statement = $self->to_statement($object);
    my @bind      = ( $statement =~ m/$$self{template}/g );
    $$self{template} =~ s/[)(]//g;
    $statement = join ' ? ', split /($$self{template})/, $statement;
    for ( my $i = 0 ; $i <= $#bind ; $i++ ) {
        $bind[$i] = $$param{ $bind[$i] } if exists $$param{ $bind[$i] };
    }
    return $statement, @bind;
}

1;

__END__

=head1 NAME

SQLAbstractObject - Преобразование SQL - запроса в структуру данных и обратно.

=head1 SYNOPSIS

   use SQLAbstractObject;
   my $sql = q/SELECT * FROM `features` LEFT JOIN ( SELECT `fid` FROM `features_product` WHERE `gid` = ~ID~ ) AS `f` ON `f`.`fid` = `features`.`id`/;

   my $soa = ObjectToStatement->new();
   my $object = $soa->object( $sql );

    # $object = {
    #   'left_join' => {
    #     'as' => [
    #       {
    #         'select' => '`fid`',
    #         'from' => '`features_product`',
    #         'where' => {
    #           'copy' => [
    #             '`gid`',
    #             '~ID~'
    #           ]
    #         }
    #       },
    #       '`f`'
    #     ]
    #   },
    #   'select' => '*',
    #   'from' => '`features`',
    #   'on' => {
    #     'copy' => [
    #       '`f`.`fid`',
    #       '`features`.`id`'
    #     ]
    #   }
    # };


  my $stmt = $soa->to_statement( $object );

    # $stmt = 'SELECT * 
    #   FROM `features` 
    #   JOIN ( 
    #     SELECT `fid` 
    #       FROM `features_product` 
    #     WHERE `gid` = ~ID~
    #    ) AS `f` 
    #     ON `f`.`fid` = `features`.`id`';

    my ( $rstmt, @bind ) = $soa->to_request( $object, { ID => 35 } );

    # $rstmt = 'SELECT * 
    #   FROM `features` 
    #   JOIN ( 
    #     SELECT `fid` 
    #       FROM `features_product` 
    #     WHERE `gid` = ?
    #    ) AS `f` 
    #     ON `f`.`fid` = `features`.`id`';

    # @bind = (35);

=head1 DESCRIPTION

Идея этого всего использовать SQL как структуру данных, изменять данные по ссылкам. Если нужно хранить как YAML, JSON.

=head2 EXPORT

=head3 C<new> - Создает новый класс.

my $soa = ObjectToStatement->new(
    keys => {
        'copy'        => '=',
        'lt'          => '<',
        'gt'          => '>',
        'ltcopy'      => '<=',
        'gtcopy'      => '>=',
        'ltgt'        => '<>',

    },
    separator => '~'
);

=head4 C<keys> - Хеш соотвествия ключей в объекте SQL - ключевым словам.

  {
        'copy'        => '=',
        'lt'          => '<',
        'gt'          => '>',
        'ltcopy'      => '<=',
        'gtcopy'      => '>=',
        'ltgt'        => '<>',

    }

=head4 C<separator> - Знак отделяющий название переменной или парамера в шаблоне ( схеме ) SQL - запроса ( '~' ).

=head4 C<template> - Регулярное выражение для получения ключей параметров для добавления в SQL запрос ( ["']*[~](\w+)[~]["']* ).

=head3 C<to_object> - Разбирает SQL - запрос в структуру данных как HASH по настройкам. См. new

=head3 C<to_statement> - Структуру данных в SQL - запрос по настройкам. См. new

=head3 C<to_request> - Структуру данных в SQL - запрос и bind-данные по настройкам. См. new


=head1 SEE ALSO


=head1 AUTHOR

Alexandr Selunin, E<lt>aka.qwars@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Alexandr Selunin

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS


=cut
