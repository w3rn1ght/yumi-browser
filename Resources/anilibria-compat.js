/*
 * AniLibria compatibility layer for iOS 12.
 *
 * The current AniLibria frontend is Tailwind 4 / React based and uses CSS
 * features and colour variables that WebKit 12 does not fully understand.
 * Without a small reset the page can end up with a black-on-black body or
 * covers stuck at opacity: 0. These rules restore readable text and reveal
 * poster images; the WebP polyfill (when enabled) replaces the actual bytes.
 */
(function () {
    if (document.getElementById('yumi-al-style')) return;

    var css = `
html,body{background-color:#0b0b10!important;color:#e8e8ea!important;}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif!important;min-height:100vh!important;}
#__next,main{opacity:1!important;visibility:visible!important;min-height:100vh;}
a{color:#9ecbff!important;}
img,.poster-loading,img[class*="poster-loading"],img[class*="opacity-0"]{opacity:1!important;}
input,textarea,select{color:#e8e8ea!important;}
::placeholder{color:#9aa0aa!important;}
`;

    var style = document.createElement('style');
    style.id = 'yumi-al-style';
    style.textContent = css;
    (document.head || document.documentElement).appendChild(style);
})();
