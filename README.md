## Setup 
```
  gem install bundler
  bundle install
```

## Running

```
  bundle exec ruby convert.rb rick-and-morty.json
  # writes rick-and-morty.xml

  head rick-and-morty.json
  
  {
 	"thread": [
  	{
	   "name": "Rick & Morty & The Media",
	   "comments": "50",
	   "views": "2,438",
	   "posts": [
	    {
	     "name": "Lantern7",
	     "url": "http://forums.previously.tv/profile/973-lantern7/",
  ...

  xmllint rick-and-morty.xml --format | head

  <?xml version="1.0"?>
  <root>
  <item>
    <name>Rick &amp; Morty &amp; The Media</name>
    <comments>50</comments>
    <views>2,438</views>
    <posts>
      <post>
        <name>Lantern7</name>
        <url>http://forums.previously.tv/profile/973-lantern7/</url>
  ...

```

