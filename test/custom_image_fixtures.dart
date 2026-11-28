import 'dart:convert';
import 'dart:typed_data';

Uint8List validJpegImageBytes() => Uint8List.fromList(
  base64Decode(
    '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsL'
    'DBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/'
    '2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMj'
    'IyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQAB'
    'AQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFAEBAAAA'
    'AAAAAAAAAAAAAAAABv/EABQRAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAhEDEQA/'
    'AIoBOKv/2Q==',
  ),
);

Uint8List validPngImageBytes() => Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR4nGNU'
    'qdjCwMAAAAYOAVLhvH2OAAAAAElFTkSuQmCC',
  ),
);

Uint8List validWebpImageBytes() => Uint8List.fromList(
  base64Decode('UklGRh4AAABXRUJQVlA4TBEAAAAvAQAAAAdQvJKUtv+BiOh/AAA='),
);
