# IPB Usernames parser
This is a Perl script that scrapes usernames from a specified website and saves them in a file.

# Requisites
* Perl 5.20.0 or later
* Coro
* URI::Simple
* File::Slurp
* Coro::Select
* Getopt::Args
* LWP::UserAgent
* LWP::Protocol::socks
* List::Util
* List::MoreUtils

# Usage

```bash
./start.pl --url <url> [--tor] [--torServer <tor_server>] [--torPassword <tor_password>] [--threads <threads_count>] [--reqLimit <requests_limit>] [--output <output_file>]
```

## Options

* url - the URL of the website to scrape (required).
* tor - use Tor for scraping (default off).
* torServer - the Tor socks5 server to use (default socks://localhost:9050).
* torPassword - the password for the Tor control protocol.
* threads - the number of asynchronous requests to use (default 10).
* reqLimit - the number of requests from one IP (default 10).
* output - the file to save the scraped usernames to (default logins.txt).

# Examples

Here are some examples of how to use this usernames scraper.


Scraping usernames from a website using Tor:

```bash
./start.pl --url https://www.example.com --tor --torServer socks://localhost:9150 --torPassword mypassword --output example_users.txt
```

Scraping usernames from a website using 50 threads:

```bash
./start.pl --url https://www.example.com --threads 50 --output example_users.txt
```
