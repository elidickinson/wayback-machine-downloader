# Wayback Machine Downloader

[![Gem Version](https://badge.fury.io/rb/wayback_machine_downloader.svg)](https://rubygems.org/gems/wayback_machine_downloader/)

This is a fork of the [Wayback Machine Downloader](https://github.com/hartator/wayback-machine-downloader). With this, you can download a website from the Internet Archive Wayback Machine.

Included here is partial content from other forks, namely those @ [ShiftaDeband](https://github.com/ShiftaDeband/wayback-machine-downloader) and [matthid](https://github.com/matthid/wayback-machine-downloader) — attributions are in the code and go to the original authors; as well as a few additional (future) features.

## Installation
Note: You need to install Ruby on your system (>= 2.3) to run this program — if you don't already have it.

1. Clone/download this repository
2. In your terminal (e.g. Command Prompt, PowerShell, Windows Terminal), navigate to the directory where you cloned/downloaded this repository
3. Navigate to `wayback_machine_downloader\bin` (psst, Windows users: open this directory in File Explorer, then press Shift + Right Click → "Open Terminal here")
4. Run:
```bash
ruby wayback_machine_downloader [options] URL
```

### Using Docker
We have a Docker image! Sorta. It's not on Docker Hub yet, but you can build it yourself. Here's how:

```bash
docker build -t wayback_machine_downloader .

docker run -it --rm wayback_machine_downloader [options] URL
```

# Constants
There are a few constants that can be edited in the `wayback_machine_downloader.rb` file for your convenience. The default values may be conservative, so you can adjust them to your needs. They are:

- `DEFAULT_TIMEOUT` - The default timeout (in seconds) for HTTP requests. Default is 30 seconds.
- `MAX_RETRIES` - The maximum number of retries for HTTP requests. Default is 3.
- `RETRY_DELAY` - The delay (in seconds) between retries for HTTP requests. Default is 2 seconds.
- `RATE_LIMIT` - The rate limit (in seconds) for HTTP requests. Default is 0.25 seconds.
- `CONNECTION_POOL_SIZE` - The size of the HTTP connection pool. Default is 10 connections.
- `HTTP_CACHE_SIZE` - The size of the HTTP cache. Default is 1000.
- `MEMORY_BUFFER_SIZE` - The size of the memory buffer (in bytes) for downloads. Default is 16KB.

---

## Instructions
### Basic usage

Run wayback_machine_downloader with the base url of the website you want to retrieve as a parameter (e.g., https://example.com):

    ruby wayback_machine_downloader https://example.com

## How it works

It will download the last version of every file present on Wayback Machine to `./websites/example.com/`. It will also re-create a directory structure and auto-create `index.html` pages to work seamlessly with Apache and Nginx. All files downloaded are the original ones and not Wayback Machine rewritten versions. This way, URLs and links structure are the same as before.

## Advanced Usage

	Usage: ruby wayback_machine_downloader https://example.com

	Download an entire website from the Wayback Machine.

	Optional options:
	    -d, --directory PATH             Directory to save the downloaded files into
					     Default is ./websites/ plus the domain name
	    -s, --all-timestamps             Download all snapshots/timestamps for a given website
	    -f, --from TIMESTAMP             Only files on or after timestamp supplied (ie. 20060716231334)
	    -t, --to TIMESTAMP               Only files on or before timestamp supplied (ie. 20100916231334)
	    -e, --exact-url                  Download only the url provided and not the full site
	    -o, --only ONLY_FILTER           Restrict downloading to urls that match this filter
					     (use // notation for the filter to be treated as a regex)
	    -x, --exclude EXCLUDE_FILTER     Skip downloading of urls that match this filter
					     (use // notation for the filter to be treated as a regex)
	    -a, --all                        Expand downloading to error files (40x and 50x) and redirections (30x)
	    -c, --concurrency NUMBER         Number of multiple files to download at a time
					     Default is one file at a time (ie. 20)
	    -p, --maximum-snapshot NUMBER    Maximum snapshot pages to consider (Default is 100)
					     Count an average of 150,000 snapshots per page
	    -l, --list                       Only list file urls in a JSON format with the archived timestamps, won't download anything
	    
## Specify directory to save files to

    -d, --directory PATH

Optional. By default, Wayback Machine Downloader will download files to `./websites/` followed by the domain name of the website. You may want to save files in a specific directory using this option.

Example:

    ruby wayback_machine_downloader https://example.com --directory downloaded-backup/
    
## All Timestamps

    -s, --all-timestamps 

Optional. This option will download all timestamps/snapshots for a given website. It will uses the timestamp of each snapshot as directory.

Example:

    ruby wayback_machine_downloader https://example.com --all-timestamps 
    
    Will download:
    	websites/example.com/20060715085250/index.html
    	websites/example.com/20051120005053/index.html
    	websites/example.com/20060111095815/img/logo.png
    	...

## From Timestamp

    -f, --from TIMESTAMP

Optional. You may want to supply a from timestamp to lock your backup to a specific version of the website. Timestamps can be found inside the urls of the regular Wayback Machine website (e.g., https://web.archive.org/web/20060716231334/http://example.com). You can also use years (2006), years + month (200607), etc. It can be used in combination of To Timestamp.
Wayback Machine Downloader will then fetch only file versions on or after the timestamp specified.

Example:

    ruby wayback_machine_downloader https://example.com --from 20060716231334

## To Timestamp

    -t, --to TIMESTAMP

Optional. You may want to supply a to timestamp to lock your backup to a specific version of the website. Timestamps can be found inside the urls of the regular Wayback Machine website (e.g., https://web.archive.org/web/20100916231334/http://example.com). You can also use years (2010), years + month (201009), etc. It can be used in combination of From Timestamp.
Wayback Machine Downloader will then fetch only file versions on or before the timestamp specified.

Example:

    ruby wayback_machine_downloader https://example.com --to 20100916231334
    
## Exact Url

	-e, --exact-url 

Optional. If you want to retrieve only the file matching exactly the url provided, you can use this flag. It will avoid downloading anything else.

For example, if you only want to download only the html homepage file of example.com:

    ruby wayback_machine_downloader https://example.com --exact-url 


## Only URL Filter

     -o, --only ONLY_FILTER

Optional. You may want to retrieve files which are of a certain type (e.g., .pdf, .jpg, .wrd...) or are in a specific directory. To do so, you can supply the `--only` flag with a string or a regex (using the '/regex/' notation) to limit which files Wayback Machine Downloader will download.

For example, if you only want to download files inside a specific `my_directory`:

    ruby wayback_machine_downloader https://example.com --only my_directory

Or if you want to download every images without anything else:

    ruby wayback_machine_downloader https://example.com --only "/\.(gif|jpg|jpeg)$/i"

## Exclude URL Filter

     -x, --exclude EXCLUDE_FILTER

Optional. You may want to retrieve files which aren't of a certain type (e.g., .pdf, .jpg, .wrd...) or aren't in a specific directory. To do so, you can supply the `--exclude` flag with a string or a regex (using the '/regex/' notation) to limit which files Wayback Machine Downloader will download.

For example, if you want to avoid downloading files inside `my_directory`:

    ruby wayback_machine_downloader https://example.com --exclude my_directory

Or if you want to download everything except images:

    ruby wayback_machine_downloader https://example.com --exclude "/\.(gif|jpg|jpeg)$/i"

## Expand downloading to all file types

     -a, --all

Optional. By default, Wayback Machine Downloader limits itself to files that responded with 200 OK code. If you also need errors files (40x and 50x codes) or redirections files (30x codes), you can use the `--all` or `-a` flag and Wayback Machine Downloader will download them in addition of the 200 OK files. It will also keep empty files that are removed by default.

Example:

    ruby wayback_machine_downloader https://example.com --all

## Only list files without downloading

     -l, --list

It will just display the files to be downloaded with their snapshot timestamps and urls. The output format is JSON. It won't download anything. It's useful for debugging or to connect to another application.

Example:

    ruby wayback_machine_downloader https://example.com --list

## Maximum number of snapshot pages to consider

    -p, --snapshot-pages NUMBER    

Optional. Specify the maximum number of snapshot pages to consider. Count an average of 150,000 snapshots per page. 100 is the default maximum number of snapshot pages and should be sufficient for most websites. Use a bigger number if you want to download a very large website.

Example:

    ruby wayback_machine_downloader https://example.com --snapshot-pages 300    

## Download multiple files at a time

    -c, --concurrency NUMBER  

Optional. Specify the number of multiple files you want to download at the same time. Allows one to speed up the download of a website significantly. Default is to download one file at a time.

Example:

    ruby wayback_machine_downloader https://example.com --concurrency 20

## Contributing

Contributions are welcome! Just submit a pull request via GitHub.

To run the tests:

    bundle install
    bundle exec rake test
