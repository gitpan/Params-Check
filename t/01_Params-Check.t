### Params::Check test suite ###

use strict;
use Test::More 'no_plan'; #tests => 23;

$^W=1;

### case 1 ###
BEGIN {
    use_ok( 'Params::Check' ) or diag "Check.pm not found.  Dying", die;

    ### need to explicitly import 'check', use_ok cannot import.
    Params::Check->import('check');
}

### make sure it's verbose, good for debugging ###
$Params::Check::VERBOSE = 0;

my $tmpl = {
    firstname   => { required   => 1, },
    lastname    => { required   => 1, },
    gender      => { required   => 1,
                     allow      => [qr/M/i, qr/F/i],
                },
    married     => { allow      => [0,1] },
    age         => { default    => 21,
                     allow      => qr/^\d+$/,
                },
    id_list     => { default    => [],
                    strict_type => 1
                },
    phone       => { allow      => sub {
                                    my %args = @_;
                                    return 1 if &valid_phone( $args{phone} );
                                }
                },
    bureau      => { default    => 'NSA',
                     no_override => 1
                },
};

my $standard = {
    firstname   => 'joe',
    lastname    => 'jackson',
    gender      => 'M',
};

my $default = {
    lastname    => 'jackson',
    firstname   => 'joe',
    married     => undef,
    gender      => 'M',
    id_list     => [],
    phone       => undef,
    age         => 21,
    bureau      => 'NSA',
};

sub valid_phone {
    my $num = shift;

    ### dutch phone numbers are 10 digits ###
    $num =~ s/[\s-]//g;

    return $num =~ /^\d{10}$/ ? 1 : 0;
}

### test defaults ###
{
    my $hash = {%$standard};

    my $args = check( $tmpl, $hash );

    is_deeply($args, $default, "Just the defaults");
}

### test missing requirements ###
{
    my $hash = {%$standard};
    delete $hash->{gender};

    my $args = check( $tmpl, $hash );

    is($args, undef, "Missing required field");
}

### remove non-template keys ###
{
    my $hash = {%$standard};
    $hash->{nonexistant} = 1;

    my $args = check( $tmpl, $hash );

    is_deeply($args, $default, q[Non-mentioned key keys are ignored]);

    {   local $Params::Check::ALLOW_UNKNOWN = 1;
        $args = check ( $tmpl, $hash );
        is( $args->{nonexistant}, $hash->{nonexistant}, q[  Except when told not to] );
    }         
}

### flexible values ###
{
    my $hash = {%$standard};
    $hash->{ID_LIST} = [qw|a b c|];

    my $args = check( $tmpl, $hash );

    is_deeply($args->{id_list}, $hash->{ID_LIST}, q[Setting non-required field]);
}

### checking strict type ###
{
    my $hash = {%$standard};
    $hash->{ID_LIST} = {};

    my $args = check( $tmpl, $hash );

    is($args, undef, q[Enforcing strict type]);
}

### check 'no_override' ###
{
    my $hash = {%$standard};
    $hash->{bureau} = 'FBI';

    my $args = check( $tmpl, $hash );

    is( $args->{bureau}, $default->{bureau},
        q[Can not change keys marked with 'no_override']
    );
}

### check 'allow' ####
{
    my $hash = {%$standard};
    $hash->{phone} = '010 - 1234567';

    my $args = check( $tmpl, $hash );

    is_deeply($args->{phone}, $hash->{phone}, q[Allowing based on subroutine]);
}

{
    my $hash = {%$standard};
    $hash->{phone} = '010 - 123456789';

    my $args = check( $tmpl, $hash );

    is($args, undef, q[Disallowing based on subroutine]);
}

{
    my $hash = {%$standard};
    $hash->{age} = '23';

    my $args = check( $tmpl, $hash );

    is($args->{age}, $hash->{age}, q[Allowing based on regex]);
}

{
    my $hash = {%$standard};
    $hash->{age} = 'fifty';

    my $args = check( $tmpl, $hash );

    is($args, undef, q[Disallowing based on regex]);
}

{
    my $hash = {%$standard};
    $hash->{married} = 1;

    my $args = check( $tmpl, $hash );

    is($args->{married}, $hash->{married}, q[Allowing based on a list]);
}

{
    my $hash = {%$standard};
    $hash->{married} = 2;

    my $args = check( $tmpl, $hash );

    is($args, undef, q[Disallowing based on a list]);
}

{
    my $hash = {%$standard};
    $hash->{gender} = 'm';

    my $args = check( $tmpl, $hash );

    is($args->{gender}, $hash->{gender}, q[Allowing based on list of regexes]);
}

{
    my $hash = {%$standard};
    $hash->{gender} = 'K';

    my $args = check( $tmpl, $hash );

    is($args, undef, q[Disallowing based on list of regexes]);
}


### checks if 'undef' is being treated correctly ###

{
    my $utmpl = {%$tmpl};
    my $hash  = {%$standard};
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join('', @_) };

    $utmpl->{married}->{allow} = undef;
    my $args = check( $utmpl, $hash );

    is( $args->{married}, undef,    'Allow undef succeeded' );
    is( $warning, '',              '   undef did not generate a warning' );
}

{
    my $utmpl = {%$tmpl};
    my $hash  = {%$standard};
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join('', @_) };

    $utmpl->{married}->{allow} = undef;
    $hash->{married} = 'foo';
    my $args = check( $utmpl, $hash );

    is ( $args, undef,      'Allow based on undef' );
    unlike( $warning, qr/uninitialized value/,         
                            '   undef did not generate a warning' );
}

{
    my $utmpl = {%$tmpl};
    my $hash  = {%$standard};
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join('', @_) };

    push @{$utmpl->{married}->{allow}}, undef;
    $hash->{married} = undef;
    my $args = check( $utmpl, $hash );

    is ( $args->{married}, undef,   'Allow based on undef in list' );
    unlike( $warning, qr/uninitialized value/,         
                            '   undef did not generate a warning' );
}

{
    my $utmpl = {%$tmpl};
    my $hash  = {%$standard};
    my $warning = '';
    local $SIG{__WARN__} = sub { $warning .= join('', @_) };

    push @{$utmpl->{married}->{allow}}, undef;
    $hash->{married} = 'foo';
    my $args = check( $utmpl, $hash );

    is ( $args, undef,      'Allow based on undef' );
    unlike( $warning, qr/uninitialized value/,         
                            '   undef did not generate a warning' );
}

### store/$NO_DUPLICATES tests ###
{
    my $utmpl   = {%$tmpl};
    my $hash    = {%$standard};    
    my $x;

    $utmpl->{firstname}->{store} = \$x;
    
    for( 0..1 ) {
        my $what = $_ ? 'Keeping' : 'Removing';
    
        local $Params::Check::NO_DUPLICATES = $_;    
        my $args = check( $utmpl, $hash );
        
        
        is($x, $hash->{firstname},         q[Storing keys in scalars] );
        is(defined $args->{firstname}, !$_,qq[$what in result set]    );  
    }
}

