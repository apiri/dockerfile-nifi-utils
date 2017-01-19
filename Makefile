.PHONY:  working clean \
	standalone-unsecure stop-standalone-unsecure \
	generate_certs

nifi_version = 1.1.1
nifi_toolkit = dependencies/nifi-toolkit-$(nifi_version)-bin.tar.gz

standalone-unsecure:
	docker-compose -f standalone/unsecure/docker-compose.yml up

stop-standalone-unsecure:
	docker-compose -f standalone/unsecure/docker-compose.yml down

# Establish working directory format and dependencies
working:
	mkdir -p working

dependencies:
	mkdir -p dependencies

working/nifi_toolkit : $(nifi_toolkit) working
	tar xf $(nifi_toolkit) -C working/
	mv working/nifi-toolkit-1.1.1 working/nifi_toolkit

$(nifi_toolkit): dependencies
	wget -P dependencies \
	 	-nc \
		http://mirrors.ocf.berkeley.edu/apache/nifi/$(nifi_version)/nifi-toolkit-$(nifi_version)-bin.tar.gz

clean:
	rm -rf working
