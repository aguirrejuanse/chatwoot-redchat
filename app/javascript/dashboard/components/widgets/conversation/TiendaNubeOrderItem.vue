<script setup>
import { computed } from 'vue';
import { format } from 'date-fns';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  order: {
    type: Object,
    required: true,
  },
});

const { t, locale } = useI18n();

const formatDate = dateString => {
  return format(new Date(dateString), 'MMM d, yyyy');
};

const formatCurrency = (amount, currency) => {
  return new Intl.NumberFormat(locale.value, {
    style: 'currency',
    currency: currency || 'ARS',
  }).format(amount);
};

const getPaymentStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-5 text-n-teal-12',
  };
  return classes[status] || 'bg-n-solid-3 text-n-slate-12';
};

const getOrderStatusI18nKey = status =>
  `CONVERSATION_SIDEBAR.TIENDA_NUBE.ORDER_STATUS.${status?.toUpperCase()}`;

const orderStatus = computed(() => {
  const { status } = props.order;
  if (!status) return '';
  return t(getOrderStatusI18nKey(status));
});

const paymentStatus = computed(() => {
  const { payment_status: status } = props.order;
  if (!status) return '';
  return t(
    `CONVERSATION_SIDEBAR.TIENDA_NUBE.PAYMENT_STATUS.${status?.toUpperCase()}`
  );
});
</script>

<template>
  <div
    class="py-3 border-b border-n-weak last:border-b-0 flex flex-col gap-1.5"
  >
    <div class="flex justify-between items-center">
      <div class="font-medium flex">
        <a
          :href="order.admin_url"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline text-n-slate-12 cursor-pointer truncate"
        >
          {{
            $t('CONVERSATION_SIDEBAR.TIENDA_NUBE.ORDER_ID', {
              id: order.number || order.id,
            })
          }}
          <i class="i-lucide-external-link pl-5" />
        </a>
      </div>
      <div
        :class="getPaymentStatusClass(order.payment_status)"
        class="text-xs px-2 py-1 rounded capitalize truncate"
        :title="paymentStatus"
      >
        {{ paymentStatus }}
      </div>
    </div>
    <div class="text-sm text-n-slate-12">
      <span class="text-n-slate-11 border-r border-n-weak pr-2">
        {{ formatDate(order.created_at) }}
      </span>
      <span class="text-n-slate-11 pl-2">
        {{ formatCurrency(order.total, order.currency) }}
      </span>
    </div>
    <div v-if="orderStatus">
      <span class="capitalize font-medium text-n-slate-11" :title="orderStatus">
        {{ orderStatus }}
      </span>
    </div>
  </div>
</template>
