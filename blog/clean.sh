#!/bin/dash
rm -r published drafts
rm blog-*
rm blogtag-*
cp reset_blog.html blog.html
cp reset_blogtitles.html blogtitles.html
cp reset_blogtags.html blogtags.html
cp -r ../../drafts .
