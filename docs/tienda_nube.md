# Integración Tienda Nube para Chatwoot

Integración nativa de Tienda Nube en Chatwoot, replicando el comportamiento de la integración de Shopify. Permite que los agentes de soporte vean las órdenes de un cliente directamente en el sidebar de la conversación, sin salir de Chatwoot.

## ¿Qué hace?

Cuando un agente abre una conversación (WhatsApp u otro canal), el sidebar muestra automáticamente las órdenes del cliente en Tienda Nube, identificándolo por su número de teléfono o email.

```
Sidebar de conversación
├── Datos del contacto
├── Conversaciones previas
└── 🛍️ Tienda Nube Orders   ← nuevo
    ├── #42 — Pagado — $1.500
    └── #38 — Pendiente — $890
```

---

## Arquitectura

La integración sigue exactamente el mismo patrón que la de Shopify:

```
Frontend (Vue)                    Backend (Rails)
─────────────────                 ──────────────────────────────────
TiendaNube.vue                    TiendaNube::CallbacksController
  └── botón "Conectar"     ──►    GET /tienda_nube/callback
      (OAuth redirect)            └── intercambia code → access_token
                                      guarda Hook en DB

TiendaNubeOrdersList.vue          Api::V1::Accounts::Integrations
  └── fetch al montar      ──►    ::TiendaNubeController
      orders for contact          ├── POST /integrations/tienda_nube/auth
                                  ├── DELETE /integrations/tienda_nube
                                  └── GET  /integrations/tienda_nube/orders
                                      └── busca cliente por email/teléfono
                                          devuelve órdenes formateadas
```

La lógica de llamadas a la API de Tienda Nube vive directamente en el controller (mismo patrón que Shopify, sin service object separado).

---

## Archivos creados

### Backend (Rails)

| Archivo | Descripción |
|---|---|
| `app/controllers/api/v1/accounts/integrations/tienda_nube_controller.rb` | Endpoints de la integración (auth, orders, destroy) |
| `app/controllers/tienda_nube/callbacks_controller.rb` | OAuth callback — intercambia el code por access_token |
| `app/helpers/tienda_nube/integration_helper.rb` | JWT helpers compartidos entre controllers |

### Frontend (Vue)

| Archivo | Descripción |
|---|---|
| `app/javascript/dashboard/api/integrations/tienda_nube.js` | Cliente API que llama al backend Rails |
| `app/javascript/dashboard/components/widgets/conversation/TiendaNubeOrdersList.vue` | Panel del sidebar — maneja fetch y estados |
| `app/javascript/dashboard/components/widgets/conversation/TiendaNubeOrderItem.vue` | Card individual de cada orden |
| `app/javascript/dashboard/routes/dashboard/settings/integrations/TiendaNube.vue` | Página Settings → Integrations → Tienda Nube |

### Configuración

| Archivo | Cambio |
|---|---|
| `config/routes.rb` | Rutas OAuth callback + endpoints de integración |
| `config/integration/apps.yml` | Registro de la app `tienda_nube` |
| `app/javascript/dashboard/i18n/locale/en/integrations.json` | Traducciones de la página de settings |
| `app/javascript/dashboard/i18n/locale/en/conversation.json` | Traducciones del sidebar |
| `app/javascript/dashboard/routes/dashboard/settings/integrations/integrations.routes.js` | Ruta frontend de settings |
| `app/javascript/dashboard/routes/dashboard/conversation/ContactPanel.vue` | Renderiza el widget en el sidebar |
| `public/dashboard/images/integrations/tienda_nube.png` | Logo de la integración (modo claro) |
| `public/dashboard/images/integrations/tienda_nube-dark.png` | Logo de la integración (modo oscuro) |

---

## Setup local

### 1. Crear la app en Tienda Nube Partners

1. Ir a [partners.tiendanube.com](https://partners.tiendanube.com) y crear una cuenta
2. Crear una nueva aplicación
3. Configurar los permisos: `read_orders`, `read_customers`
4. Configurar la **Redirect URL**:
   ```
   http://localhost:3000/tienda_nube/callback
   ```
5. Guardar el **App ID** y el **Client Secret**

### 2. Configurar las credenciales en Chatwoot

**Opción A — SuperAdmin UI:**

Ir a `{url}/super_admin/installation_configs` y agregar:

```
TIENDA_NUBE_CLIENT_ID     → App ID de Tienda Nube Partners
TIENDA_NUBE_CLIENT_SECRET → Client Secret de Tienda Nube Partners
```

**Opción B — Variables de entorno:**

```bash
TIENDA_NUBE_CLIENT_ID=123
TIENDA_NUBE_CLIENT_SECRET=abc123secret
```

### 3. Levantar el proyecto

```bash
overmind start -f Procfile.dev
```

No hay migraciones nuevas — la integración usa el modelo `Integrations::Hook` existente.

### 4. Conectar la integración

1. Ir a **Settings → Integrations → Tienda Nube**
2. Hacer click en **Connect**
3. Autorizar la app en Tienda Nube
4. Chatwoot redirige de vuelta con la integración activa

### 5. Probar en el sidebar

1. Abrir una conversación con un contacto que tenga email o teléfono registrado en la tienda
2. El accordion **"Tienda Nube Orders"** aparece en el sidebar derecho
3. Las órdenes del cliente se cargan automáticamente

---

## Cómo funciona el OAuth

```
1. Agente hace click en "Conectar" en Settings → Integrations → Tienda Nube

2. Frontend llama a POST /integrations/tienda_nube/auth
   → Controller genera JWT firmado con TIENDA_NUBE_CLIENT_SECRET
   → Devuelve redirect_url a Tienda Nube

3. Frontend redirige al navegador a:
   https://www.tiendanube.com/apps/{app_id}/authorize?
     client_id={id}&response_type=code&state={JWT}

4. El merchant autoriza la app en Tienda Nube

5. Tienda Nube redirige a:
   {chatwoot}/tienda_nube/callback?code=xyz&state={JWT}

6. CallbacksController:
   - Verifica el JWT del state para recuperar el account_id
   - Intercambia el code por access_token:
     POST https://www.tiendanube.com/apps/{app_id}/authorize/token
   - Guarda Hook con access_token, user_id (= store_id) y store_domain (obtenido de GET /store)

7. Redirige al agente de vuelta a la página de integración
```

---

## Diferencias clave vs Shopify

| | Shopify | Tienda Nube |
|---|---|---|
| Auth header | `X-Shopify-Access-Token` | `Authentication: bearer {token}` |
| Token expiry | Expira | **No expira** (solo si desinstalan la app) |
| Store identifier | `shop` param en OAuth | `user_id` en la respuesta del token |
| API base URL | `{shop}.myshopify.com/admin/api` | `api.tiendanube.com/v1/{store_id}` |
| Buscar cliente | `GET /customers/search.json?query=` | `GET /customers?q={email_o_tel}` |
| Service object | Sí | No — lógica directa en el controller |

---

## Cómo probar

1. Configurar las credenciales (SuperAdmin UI o `.env`) con el App ID y Client Secret de Tienda Nube Partners
2. Ir a **Settings → Integrations → Tienda Nube** → hacer click en **Connect**
3. Completar el OAuth en Tienda Nube y verificar que redirige de vuelta a Chatwoot
4. Abrir una conversación con un contacto cuyo email o teléfono exista en la tienda
5. El accordion **"Tienda Nube Orders"** en el sidebar debe mostrar sus órdenes
6. Cada orden incluye un link al panel de admin de la tienda (`{store_domain}/admin/orders/{id}`)
