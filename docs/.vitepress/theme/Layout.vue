<template>
  <Layout>
    <slot />
    <div id="lightbox-modal" style="display:none;" onclick="closeLightbox()">
      <img id="lightbox-img" src="" alt="Büyük Görsel" />
    </div>
  </Layout>
</template>

<script setup>
import DefaultTheme from 'vitepress/theme'
const { Layout } = DefaultTheme
</script>