#!/usr/bin/env perl
# Genere localization/TimeOut.csv depuis src/shared/Translations.luau, au format
# exact attendu par l'import du portail de traduction Roblox
# (Creator Dashboard -> Localization -> Table Management).
#
# Le module Lua reste la source de verite : relancer ce script apres chaque
# modification de traduction, puis reimporter le CSV.
#
#   perl localization/generate-csv.pl
#
# FORMAT -- releve sur un export de la table depuis le Dashboard, pas sur la doc
# (qui decrit un ordre de colonnes different et des codes qui font echouer
# l'import avec "Language(s) not supported") :
#
#   BOM UTF-8, puis
#   Key,Example,Source,Context,Game Locations,<code>,<code> translator type,...
#
# Les codes de langue du portail ne sont PAS ceux de Translations.luau : Roblox
# attend le code nu (de, it, ru, tr, ja, ko) partout ou la langue n'a pas de
# variante regionale, et "zh-hans" pour le chinois simplifie. Les variantes
# regionales existent en plus (en-us, es-es, pt-br...). D'ou la table ci-dessous.
#
# Rien de tout ca ne touche au jeu : a l'execution, Locale.luau lit Translations
# directement, et retombe sur la langue seule si le LocaleId du joueur n'a pas de
# correspondance exacte ("de" trouve la table "de-de").

use strict;
use warnings;

my $SOURCE_LOCALE = "fr-fr";
my $INPUT = "src/shared/Translations.luau";
my $OUTPUT = "localization/TimeOut.csv";

# Colonnes de langue de l'export Roblox, dans leur ordre d'origine, et la locale
# de Translations.luau qui les alimente (undef = colonne laissee vide).
#
# On ne remplit que les colonnes qu'on peut remplir sans inventer : le code nu
# (qui couvre toute la langue, variantes comprises) et la variante exacte d'ou
# vient le texte. en-gb, es-mx et pt-pt restent vides -- ils retombent sur en/es/pt
# plutot que de se voir attribuer un texte ecrit pour une autre region. fr-fr et
# fr-ca aussi : le francais est la langue source, il vit dans la colonne Source.
my @COLUMNS = (
	["en", "en-us"],
	["es", "es-es"],
	["pt", "pt-br"],
	["de", "de-de"],
	["it", "it-it"],
	["ru", "ru-ru"],
	["tr", "tr-tr"],
	["ja", "ja-jp"],
	["ko", "ko-kr"],
	["zh-hans", "zh-cn"],
	["en-us", "en-us"],
	["en-gb", undef],
	["es-es", "es-es"],
	["es-mx", undef],
	["pt-br", "pt-br"],
	["pt-pt", undef],
	["fr-fr", undef],
	["fr-ca", undef],
);

open my $in, "<:encoding(UTF-8)", $INPUT or die "lecture $INPUT : $!";
my $lua = do { local $/; <$in> };
close $in;

my (%strings, %seen);

while ($lua =~ /\["([a-z-]+)"\] = \{(.*?)\n\t\},/gs) {
    my ($locale, $body) = ($1, $2);
    $seen{$locale} = 1;

    while ($body =~ /^\t\t([A-Za-z_0-9]+) = "(.*)",$/gm) {
        my ($key, $value) = ($1, $2);

        # Le source Lua contient la sequence \n en deux caracteres ; le CSV doit
        # porter un vrai saut de ligne, sinon le joueur verrait "\n" a l'ecran.
        $value =~ s/\n/\n/g;

        # ":duration" et ":text" sont des conventions internes a Locale.luau.
        # L'import du portail refuse ces specificateurs ("Unknown format
        # specifier"), donc le CSV ne porte que "{nom}", comme la
        # LocalizationTable construite en jeu.
        $value =~ s/\{(\w+):\w+\}/{$1}/g;

        $strings{$locale}{$key} = $value;
    }
}

die "aucune locale trouvee dans $INPUT" unless %seen;
die "locale source $SOURCE_LOCALE absente" unless $strings{$SOURCE_LOCALE};

# Une langue traduite que le portail n'accepte pas passerait inapercue sans ca.
for my $locale (sort keys %seen) {
    next if $locale eq $SOURCE_LOCALE;
    next if grep { defined $_->[1] && $_->[1] eq $locale } @COLUMNS;
    warn "ATTENTION : $locale n'a aucune colonne dans l'export Roblox\n";
}

my @keys = sort keys %{ $strings{$SOURCE_LOCALE} };

# Guillemets seulement quand la valeur en a besoin : l'export de Roblox n'en met
# pas non plus, et son analyseur n'a pas a etre teste sur nos habitudes.
sub cell {
    my $value = shift;
    $value = "" unless defined $value;
    return $value unless $value =~ /[",\r\n]/;
    $value =~ s/"/""/g;
    return "\"$value\"";
}

open my $out, ">:encoding(UTF-8)", $OUTPUT or die "ecriture $OUTPUT : $!";
print $out "\x{FEFF}"; # BOM UTF-8, comme l'export du Dashboard

my @header = ("Key", "Example", "Source", "Context", "Game Locations");
push @header, ($_->[0], "$_->[0] translator type") for @COLUMNS;
print $out join(",", map { cell($_) } @header), "\r\n";

for my $key (@keys) {
    my @row = ($key, "", $strings{$SOURCE_LOCALE}{$key}, "", "");

    for my $column (@COLUMNS) {
        my ($name, $locale) = @$column;
        push @row, (defined $locale ? $strings{$locale}{$key} : ""), "";
    }

    print $out join(",", map { cell($_) } @row), "\r\n";
}

close $out;

my @filled = map { $_->[0] } grep { defined $_->[1] } @COLUMNS;
printf "%s : %d cles, %d colonnes remplies (%s)\n",
    $OUTPUT, scalar(@keys), scalar(@filled), join(" ", @filled);
