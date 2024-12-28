image:
	docker build -t zola .

serve: image
	docker run -u 1000:1000 -p 1111:1111 -it -v $(CURDIR)/src:/srv zola zola serve -i 0.0.0.0
