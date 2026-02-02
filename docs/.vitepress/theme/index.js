import DefaultTheme from 'vitepress/theme'
import './custom.css'

export default {
    ...DefaultTheme,
    enhanceApp({ app, router, siteData }) {
        DefaultTheme.enhanceApp && DefaultTheme.enhanceApp({ app, router, siteData });

        if (typeof window !== 'undefined') {
            window.openLightbox = function (img) {
                document.getElementById('lightbox-modal').style.display = 'flex';
                document.getElementById('lightbox-img').src = img.src;
            }
            window.closeLightbox = function () {
                document.getElementById('lightbox-modal').style.display = 'none';
            }
        }
    }
}