### Params::Check test suite ###

use strict;
use Test::More tests => 49;

$^W=1;

### case 1 ###
BEGIN {
    use_ok( 'Params::Check' ) or diag "Check.pm not found.  Dying", die;

    ### need to explicitly import 'check', use_ok cannot import.
    Params::Check->import(qw[check last_error allow]);
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
                                    return 1 if &valid_phone( @_ );
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
    my $num = pop;

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
    like(last_error(), qr/^Required option 'gender' is not provided/,
            "Error string as expected" );

}

### remove non-template keys ###
{
    my $hash = {%$standard};
    $hash->{nonexistant} = 1;

    my $args = check( $tmpl, $hash );

    is_deeply($args, $default, q[Non-mentioned key keys are ignored]);
    like( last_error(), qr/^Key 'nonexistant' is not a valid key/,
            "Error string as expected" );  

    {   local $Params::Check::ALLOW_UNKNOWN = 1;
        $args = check ( $tmpl, $hash );
        is( $args->{nonexistant}, $hash->{nonexistant}, 
            q[  Except when told not to] );
        is( last_error(), "", "Error string as expected" );  
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
    like( last_error(), qr/^Key 'id_list' is of invalid type/,
            "Error string as expected" );
}

### check 'no_override' ###
{
    my $hash = {%$standard};
    $hash->{bureau} = 'FBI';

    my $args = check( $tmpl, $hash );

    is( $args->{bureau}, $default->{bureau},
        q[Can not change keys marked with 'no_override']
    );
    like( last_error(), qr/^You are not allowed to override key 'bureau'/,
            "Error string as expected" );

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
    like( last_error(), qr/^Key 'phone' is of invalid type/,
            "Error string as expected" );
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
    like( last_error(), qr/^Key 'age' is of invalid type/,
            "Error string as expected" );
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
    like( last_error(), qr/^Key 'married' is of invalid type/,
            "Error string as expected" );
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
    like( last_error(), qr/^Key 'gender' is of invalid type/,
            "Error string as expected" );
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

### $PRESERVE_CASE check ###
{
    my $tmpl =  { Foo => { default => 1 } };
    my $try =   { FOO => 2 };

    for (0..1) {
        local $Params::Check::PRESERVE_CASE = $_;
    
        my $expect = $_ ? { Foo => 1 } : { foo => 2 };
        my $state =  $_ ? "" : " not";
    
        my $rv = check( $tmpl, $try );
        is_deeply( $rv, $expect, "Check while". $state ." preserving case" ); 
    }               
}

### defined check/$ONLY_ALLOW_DEFINED tests ###
{
    {   my $utmpl   = { key => { defined => 1 } };
        my $rv      = check( $utmpl, { key => undef } );

        ok(!$rv, q[undef value not allowed when 'defined' is enabled]);
    }
    {   local $Params::Check::ONLY_ALLOW_DEFINED = 1;
        my $utmpl   = { key => { default => 1 } };
        my $rv      = check( $utmpl, { key => undef } );
        
        ok(!$rv, q[undef value not allowed if '$ONLY_ALLOW_DEFINED' is true]);
    }
}


### allow tests ###
ok( allow( 42, qr/^\d+$/ ), "Allow based on regex" );
ok( allow( $0, $0),         "   Allow based on string" );
ok( allow( 42, [0,42] ),    "   Allow based on list" );
ok( allow( 42, [50,sub{1}]),"   Allow based on list containing sub");
ok(!allow( $0, qr/^\d+$/ ), "Disallowing based on regex" );
ok(!allow( 42, $0 ),        "   Disallowing based on string" );
ok(!allow( 42, [0,$0] ),    "   Disallowing based on list" );
ok(!allow( 42, [50,sub{0}]),"   Disallowing based on list containing sub");



