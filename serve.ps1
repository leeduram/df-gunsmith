# Local preview of the website: http://localhost:8080/  (close the window to stop)
$root = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'web'))
$types = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript; charset=utf-8'; '.css' = 'text/css; charset=utf-8';
            '.json' = 'application/json; charset=utf-8'; '.png' = 'image/png'; '.webp' = 'image/webp'; '.svg' = 'image/svg+xml'; '.ico' = 'image/x-icon' }
$l = New-Object Net.HttpListener
$l.Prefixes.Add('http://localhost:8080/')
$l.Start()
Write-Host 'Preview running: http://localhost:8080/'
while ($l.IsListening) {
  try { $c = $l.GetContext() } catch { continue }
  try {
    $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
    if (-not $p -or $p.EndsWith('/')) { $p = $p + 'index.html' }   # weapon pages: w/<id>/ -> w/<id>/index.html
    $f = [IO.Path]::GetFullPath((Join-Path $root $p))
    if (-not $f.StartsWith($root) -or -not (Test-Path $f -PathType Leaf)) { $c.Response.StatusCode = 404 }
    else {
      $b = [IO.File]::ReadAllBytes($f)
      $ct = $types[[IO.Path]::GetExtension($f).ToLower()]; if ($ct) { $c.Response.ContentType = $ct }
      # pictures change at most once a day; page and data are checked every time
      $c.Response.Headers.Add('Cache-Control', $(if ($p -like 'img/*') { 'max-age=3600' } else { 'no-cache' }))
      $c.Response.ContentLength64 = $b.Length
      $c.Response.OutputStream.Write($b, 0, $b.Length)
    }
  } catch { try { $c.Response.StatusCode = 500 } catch { } }
  # a browser that stops waiting (page changed, picture no longer needed) must not stop the server
  try { $c.Response.Close() } catch { }
}
