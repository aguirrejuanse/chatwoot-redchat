<script setup>
import { ref, computed, onMounted } from 'vue';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import Integration from './Integration.vue';
import integrationAPI from 'dashboard/api/integrations';

import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

defineProps({
  error: {
    type: String,
    default: '',
  },
});

const store = useStore();
const { t } = useI18n();
const integrationLoaded = ref(false);
const isSubmitting = ref(false);
const integration = useFunctionGetter(
  'integrations/getIntegration',
  'tienda_nube'
);

const integrationAction = computed(() => {
  if (integration.value.enabled) {
    return 'disconnect';
  }
  return 'connect';
});

const handleConnect = async () => {
  try {
    isSubmitting.value = true;
    const { data } = await integrationAPI.connectTiendaNube();

    if (data.redirect_url) {
      window.location.href = data.redirect_url;
    }
  } catch {
    // swallow — redirect on success, nothing to show on failure
  } finally {
    isSubmitting.value = false;
  }
};

const initializeIntegration = async () => {
  await store.dispatch('integrations/get', 'tienda_nube');
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeIntegration();
});
</script>

<template>
  <SettingsLayout :is-loading="!integrationLoaded">
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.TIENDA_NUBE.HEADER')"
        description=""
        feature-name="tienda_nube_integration"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <Integration
          :integration-id="integration.id"
          :integration-logo="integration.logo"
          :integration-name="integration.name"
          :integration-description="integration.description"
          :integration-enabled="integration.enabled"
          :integration-action="integrationAction"
          :delete-confirmation-text="{
            title: t('INTEGRATION_SETTINGS.TIENDA_NUBE.DELETE.TITLE'),
            message: t('INTEGRATION_SETTINGS.TIENDA_NUBE.DELETE.MESSAGE'),
          }"
        >
          <template #action>
            <Button
              teal
              :label="t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
              :is-loading="isSubmitting"
              @click="handleConnect"
            />
          </template>
        </Integration>
        <div
          v-if="error"
          class="flex items-center justify-center flex-1 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow p-6"
        >
          <p class="text-n-ruby-9">
            {{ t('INTEGRATION_SETTINGS.TIENDA_NUBE.ERROR') }}
          </p>
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
