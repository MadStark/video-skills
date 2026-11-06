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
    const err = $();
    const d = url.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(0, null, null, err);
    if (!d || d.isNil()) {
      let msg = '';
      try { msg = err.localizedDescription.js; } catch (e) {}
      throw new Error('bookmark creation failed for ' + argv[1] + ' ' + msg);
    }
    return d.base64EncodedStringWithOptions(0).js;
  }
  throw new Error('usage: bookmark.js path <b64> | make <folder>');
}
