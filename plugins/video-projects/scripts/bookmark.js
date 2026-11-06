// macOS bookmark helper for Final Cut Pro library Settings.plist entries.
// Usage:
//   osascript -l JavaScript bookmark.js path <base64-bookmark>   -> prints the path stored in the bookmark
//   osascript -l JavaScript bookmark.js make <absolute-folder>    -> prints a new base64 bookmark for that folder
ObjC.import('Foundation');

function run(argv) {
  const cmd = argv[0];
  if (cmd === 'path') {
    const data = $.NSData.alloc.initWithBase64EncodedStringOptions($(argv[1]), 0);
    if (!data || data.isNil()) throw new Error('invalid base64 bookmark');
    const vals = $.NSURL.resourceValuesForKeysFromBookmarkData($([$.NSURLPathKey]), data);
    if (!vals || vals.isNil()) throw new Error('could not read bookmark');
    const p = vals.objectForKey($.NSURLPathKey);
    if (!p || p.isNil()) throw new Error('bookmark has no path');
    return p.js;
  }
  if (cmd === 'make') {
    const url = $.NSURL.fileURLWithPath($(argv[1]));
    // Pass nil (not null, which JXA bridges to NSNull) for the URL/keys args and the
    // error out-param; a Ref() error pointer segfaults osascript on failure.
    const d = url.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(0, $(), $(), $());
    if (!d || d.isNil()) throw new Error('bookmark creation failed for ' + argv[1] + ' (does the folder exist?)');
    return d.base64EncodedStringWithOptions(0).js;
  }
  throw new Error('usage: bookmark.js path <b64> | make <folder>');
}
