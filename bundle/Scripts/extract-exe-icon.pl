#!/usr/bin/perl
# Writes a Windows exe's main icon (its first icon group, every size) to a .ico file.
# Usage: extract-exe-icon.pl game.exe out.ico
use strict;
use warnings;

my ($exe, $out_path) = @ARGV;
open my $fh, '<:raw', $exe or die "can't read $exe: $!\n";
my $d = do { local $/; <$fh> };
close $fh;

my $pe = unpack 'V', substr($d, 0x3c, 4);
die "not a PE file\n" unless substr($d, $pe, 4) eq "PE\0\0";
my $nsec    = unpack 'v', substr($d, $pe + 6, 2);
my $optsize = unpack 'v', substr($d, $pe + 20, 2);
my $opt     = $pe + 24;
my $is_pe32_plus = unpack('v', substr($d, $opt, 2)) == 0x20b;
my $rsrc_rva = unpack 'V', substr($d, $opt + ($is_pe32_plus ? 112 : 96) + 2 * 8, 4);
die "no resources\n" unless $rsrc_rva;

my @sections;
for my $i (0 .. $nsec - 1) {
    my ($vsize, $va, $rawsize, $rawptr) = unpack 'V4', substr($d, $opt + $optsize + 40 * $i + 8, 16);
    push @sections, [$va, ($vsize > $rawsize ? $vsize : $rawsize), $rawptr];
}
sub file_offset {
    my $rva = shift;
    for (@sections) { return $rva - $_->[0] + $_->[2] if $rva >= $_->[0] && $rva < $_->[0] + $_->[1] }
    die "address outside sections\n";
}
my $base = file_offset($rsrc_rva);

# Resource directories: [name-or-id, offset]; a set high bit on the offset means subdirectory.
sub entries {
    my $dir = shift;
    my ($named, $ids) = unpack 'v2', substr($d, $base + $dir + 12, 4);
    return map { [unpack 'V2', substr($d, $base + $dir + 16 + 8 * $_, 8)] } 0 .. $named + $ids - 1;
}
sub subdir_for_id {
    my ($dir, $id) = @_;
    for (entries($dir)) { return $_->[1] & 0x7fffffff if $_->[0] == $id }
    return;
}
sub first_data {  # follows the first entry at each level down to the data
    my $o = shift;
    while (1) {
        my $next = (entries($o))[0][1];
        if ($next & 0x80000000) { $o = $next & 0x7fffffff; next }
        my ($rva, $size) = unpack 'V2', substr($d, $base + $next, 8);
        return substr($d, file_offset($rva), $size);
    }
}

my $icons  = subdir_for_id(0, 3)  // die "no icons\n";       # RT_ICON
my $groups = subdir_for_id(0, 14) // die "no icon group\n";  # RT_GROUP_ICON
my $group  = first_data($groups);
my $count  = unpack 'v', substr($group, 4, 2);

my ($dir_entries, $images) = ('', '');
my $offset = 6 + 16 * $count;
for my $i (0 .. $count - 1) {
    my ($w, $h, $colors, $reserved, $planes, $bpp, undef, $id) = unpack 'C4 v2 V v', substr($group, 6 + 14 * $i, 14);
    my $sub = subdir_for_id($icons, $id) // die "icon $id missing\n";
    my $img = first_data($sub);
    $dir_entries .= pack 'C4 v2 V V', $w, $h, $colors, $reserved, $planes, $bpp, length($img), $offset;
    $images .= $img;
    $offset += length $img;
}

open my $out, '>:raw', $out_path or die "can't write $out_path: $!\n";
print $out pack('v3', 0, 1, $count), $dir_entries, $images;
close $out;
