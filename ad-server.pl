#!/usr/bin/env perl

use strict;
use Socket;
use IO::Socket;
use JSON qw( decode_json encode_json );
use Data::Dumper;

# Simple http server in Perl

# Setup and create socket

my $port = shift;
defined($port) or die "Usage: $0 portno\n";

my $DOCUMENT_ROOT = $ENV{'HOME'} . "/public_html";
my $server = new IO::Socket::INET(Proto => 'tcp',
                                  LocalPort => $port,
                                  Listen => SOMAXCONN,
                                  Reuse => 1);
$server or die "Unable to create server socket: $!" ;

# Await requests and handle them as they arrive

my $start = time();

while (my $client = $server->accept()) {
    $client->autoflush(1);
    my %request = ();
    my %data;
	
    {
#-------- Read Request ---------------

        local $/ = Socket::CRLF;
        while (<$client>) {
            chomp; # Main http request
            if (/\s*(\w+)\s*([^\s]+)\s*HTTP\/(\d.\d)/) {
                $request{METHOD} = uc $1;
                $request{URL} = $2;
                $request{HTTP_VERSION} = $3;
            } # Standard headers
            elsif (/:/) {
                (my $type, my $val) = split /:/, $_, 2;
                $type =~ s/^\s+//;
                foreach ($type, $val) {
                        s/^\s+//;
                        s/\s+$//;
                }
                $request{lc $type} = $val;
            } # POST data
            elsif (/^$/) {
                read($client, $request{CONTENT}, $request{'content-length'})
                    if defined $request{'content-length'};
                last;
            }
        }
    }

#-------- SORT OUT METHOD  ---------------

    if ($request{METHOD} eq 'GET') {
        if ($request{URL} =~ /(.*)\?(.*)/) {
                $request{URL} = $1;
                $request{CONTENT} = $2;
                $data{"_content"} = $request{CONTENT};
        } else {
                %data = ();
        }
        $data{"_method"} = "GET";
    } elsif ($request{METHOD} eq 'POST') {
                $data{"_content"} = $request{CONTENT};
                $data{"_method"} = "POST";
    } else {
        $data{"_method"} = "ERROR";
    }

#------- Serve file ----------------------

    my $localfile = $DOCUMENT_ROOT.$request{URL};

# Send Response
    if($request{METHOD} eq 'POST') {	 
		print $client "HTTP/1.0 200 OK", Socket::CRLF;
		print $client "Content-type: text/html", Socket::CRLF;
		print $client Socket::CRLF;
		my $buffer = decode_json( $data{"_content"} );
		my $d = Data::Dumper->new([$buffer],[]);
		print $client $d->Dump;
		my $partner_id = $buffer->{"partner_id"};
		my $ad_content = $buffer->{"ad_content"};
		my $duration = $buffer->{"duration"};
		my $time = time();
		$ad_content = "$partner_id\n$ad_content\n$duration\n$time";
		opendir(THISDIR,".");
		my @ad_files = grep /^.*$partner_id\.txt$/, readdir THISDIR;
		closedir(THISDIR);
		if($#ad_files > -1) { $ad_content = "\[EOA\]\n$ad_content"; } 
		open(FILE,">>$partner_id\.txt");
		print FILE "$ad_content\n";
		close(FILE);
		$data{"_status"} = "200";
	} else {
		if($request{URL} =~ /^\/\w+\/S+\/w+$/) {
			if(open(FILE,"<$localfile\.txt")) {
				print $client "HTTP/1.0 200 OK", Socket::CRLF;
				print $client "Content-type: text/html", Socket::CRLF;
				print $client Socket::CRLF;
				my $buffer;
				read(FILE, $buffer, 99999999);
				if($buffer =~ /^\w+\n(.*)\n(\d+)\n(\d+)\n$/) {
					my $ad = $1;
					my $dur = $2;
					my $create_time = $3;
					my $current_time = time();
					if(($current_time - $create_time) <= $dur) {
						print $client $1;
					} else {
						print $client "Ad has expired!", Socket::CRLF;
					}
				}
				$data{"_status"} = "200";
				close(FILE);
			} else {
				print $client "HTTP/1.0 404 Not Found", Socket::CRLF;
				print $client Socket::CRLF;
				print $client "404 Document Not Found: "."$localfile\.txt";
				$data{"_status"} = "404";
			}
		} else {
			 opendir(THISDIR,".");
			 my @ad_files = grep /^.*\.txt$/, readdir THISDIR;
			 my $json_str = "\{";
			 foreach(@ad_files) {
				 if(open(FILE,"<$_")) {
					$json_str = "";
					my $buffer;
					read(FILE, $buffer, 4096);
					my @ads = split /\[EOA\]\n/, $buffer;
					foreach(@ads) {
						if($_ =~ /^(\w+)\n(.*)\n(\d+)\n(\d+)\n$/) {
							my $partner_id = $1;
							my $ad = $2;
							my $dur = $3;
							my $create_time = $4;
							my %ad_hash = ('partner_id' => $partner_id, 
										   'ad_content' => $ad,
										   'duration' => $dur,
										   'created' => $create_time);
							$json_str = encode_json \%ad_hash;
						}					
						print $client $json_str;
					 }					 					 
				 }
				 close(FILE);
			 }
			closedir(THISDIR);
		}
	}

# ----------- Close Connection and loop ------------------

    close $client;
}

