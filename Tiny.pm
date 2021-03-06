use v6;

class CSS::Tiny:ver<1.19>;

has %!styles handles <at_key assign_key list pairs keys values kv>;

# Create an object from a file
method read($file) {
	# Check the file
    given $file.IO {
        fail "The file '$file' does not exist"          unless .e;
        fail "'$file' is a directory, not a file"       unless .f;
        fail "Insufficient permissions to read '$file'" unless .r;
    }

	# Read the file
    my $contents = try { slurp($file) } orelse fail $!;

	self.read_string($contents)
}

# Create an object from a string
method read_string($string) {
	my $self = self // self.new;

    my grammar SimpleCSS {
        rule TOP {
            <?> <style>* [ $ || { die "Failed to parse CSS" } ]
        }
        rule style {
            <style_name>+ %% [ <?> ',' ] '{'
                <property>+ %% [ <?> ';' ]
            '}'
        }
        token style_name { [ <-[\s,{]>+ ]+ % [\s+] }
        rule property {
            $<key>=[<[\w.-]>+] ':' $<val>=[<-[\s;]>+]
        }
        token ws { \s* | '/*' .+? '*/' }
    }

	# Parse each style.
	for SimpleCSS.parse($string)<style>.list -> $s {
		# Initialize empty hash per style.
		my @styles = $s<style_name>.map(~*);
		for @styles { $self{$_} //= {} }

		# Add properties.
		for $s<property>.list -> $p {
			for @styles { $self{$_}{lc $p<key>} = ~$p<val> }
		}
	}

	$self
}

# Copy an object
method clone {
    my %styles_copy;
    for %!styles.kv -> $style, %properties {
        %styles_copy{$style} = { %properties };
    }
    self.new(styles => %styles_copy)
}

# Save an object to a file
method write($file) {
	try { spurt($file, self.write_string) } orelse fail $!;
}

# Save an object to a string
method write_string {

	# Iterate over the styles
	# Note: We use 'reverse' in the sort to avoid a special case related
	# to A:hover even though the file ends up backwards and looks funny.
	# See http://www.w3.org/TR/CSS2/selector.html#dynamic-pseudo-classes
	my $contents = '';
	for self.keys.sort.reverse -> $style {
		$contents ~= "$style \{\n";
		for self{$style}.keys.sort {
			$contents ~= "\t" ~ lc($_) ~ ": {self{$style}{$_}};\n";
		}
		$contents ~= "}\n";
	}

	return $contents;
}

# Generate a HTML fragment for the CSS
method html {
	my $css = self.write_string or return '';
	return "<style type=\"text/css\">\n<!--\n{$css}-->\n</style>";
}

# Generate an xhtml fragment for the CSS
method xhtml {
	my $css = self.write_string or return '';
	return "<style type=\"text/css\">\n/* <![CDATA[ */\n{$css}/* ]]> */\n</style>";
}
