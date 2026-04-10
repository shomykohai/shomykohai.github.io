(function () {
  function ready(fn) {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  }

  function isImageHref(href) {
    if (!href) return false;
    return /\.(png|jpe?g|gif|webp|bmp|tiff|svg)(\?.*)?(#.*)?$/i.test(href);
  }

  ready(function () {
    var post = document.querySelector(".post");
    if (!post) return;

    var images = Array.prototype.slice.call(post.querySelectorAll("img"));
    if (!images.length) return;

    images.forEach(function (img) {
      var src = img.currentSrc || img.src;
      var link = img.closest("a");

      if (link) {
        var href = link.getAttribute("href");
        var sameSrc =
          href && (href === src || href === img.src || href === img.currentSrc);
        if (!sameSrc && !isImageHref(href)) {
          return;
        }
      } else {
        link = document.createElement("a");
        link.href = src;
        link.classList.add("pswp-image");
        img.parentNode.insertBefore(link, img);
        link.appendChild(img);
      }

      link.classList.add("pswp-image");
      link.setAttribute("data-pswp-src", src);

      var setSize = function () {
        var w = img.naturalWidth || img.width;
        var h = img.naturalHeight || img.height;
        if (w && h) {
          link.setAttribute("data-pswp-width", String(w));
          link.setAttribute("data-pswp-height", String(h));
        }
      };

      if (img.complete) {
        setSize();
      } else {
        img.addEventListener("load", setSize, { once: true });
      }
    });

    import("https://unpkg.com/photoswipe@5.4.4/dist/photoswipe-lightbox.esm.js")
      .then(function (module) {
        var PhotoSwipeLightbox = module.default;
        var lightbox = new PhotoSwipeLightbox({
          gallery: ".post",
          children: "a.pswp-image",
          pswpModule: function () {
            return import("https://unpkg.com/photoswipe@5.4.4/dist/photoswipe.esm.js");
          },
          showHideAnimationType: "zoom",
        });

        lightbox.init();
      })
      .catch(function () {});
  });
})();
