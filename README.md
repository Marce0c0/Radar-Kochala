# Radar Kochala (Reporta Cochabamba) 📍

Aplicación móvil desarrollada en Flutter y Supabase para la gestión de incidentes urbanos y baches en la ciudad de Cochabamba, Bolivia. 

Incluye validación fotográfica mediante Inteligencia Artificial (Gemini), persistencia offline (SQLite) y paneles de control administrativo para operadores.

## 🚀 Características Principales

*   **Reportes Georreferenciados:** Restringido a las coordenadas exactas de Cochabamba.
*   **Validación de Inteligencia Artificial (Anti-Spam):** Gemini analiza la imagen del bache o incidente y genera un nivel de confianza (`is_ai_verified`).
*   **Modo Offline Resiliente:** Si el usuario no tiene internet, los reportes se encolan usando SQLite y se sincronizan silenciosamente en segundo plano al recuperar la conexión.
*   **Paginación Infinita:** Manejo eficiente de memoria en el *Dashboard* del operador mediante lazy-loading de reportes.
*   **Optimización de Imágenes:** Compresión nativa en la captura para ahorro de ancho de banda.

---

## 🛠️ Configuración (Setup)

Para correr este proyecto en tu propia máquina, necesitas configurar tus propias claves de API de **Supabase** (Base de Datos / Autenticación) y **Google Gemini** (Inteligencia Artificial).

1. Clona el repositorio:
   ```bash
   git clone https://github.com/Marce0c0/Radar-Kochala.git
   cd Radar-Kochala
   ```

2. Instala las dependencias:
   ```bash
   flutter pub get
   ```

3. **Configura las variables de entorno:**
   - En la raíz del proyecto encontrarás un archivo llamado `.env.example`.
   - Renómbralo o cópialo para crear un nuevo archivo llamado exactamente `.env`.
   - Abre el archivo `.env` y pega tus claves de Supabase y Gemini:
     ```env
     # Claves de Supabase (Obligatorias)
     SUPABASE_URL=tu_url_de_supabase_aqui
     SUPABASE_ANON_KEY=tu_anon_key_de_supabase_aqui

     # Clave de Gemini AI (Opcional, para verificación inteligente)
     GEMINI_API_KEY=tu_api_key_de_gemini_aqui
     ```

4. Ejecuta la aplicación:
   ```bash
   flutter run
   ```

## 🔐 Notas de Seguridad
* Nunca subas tu archivo `.env` a GitHub. Ya está ignorado por defecto en el `.gitignore`.
* Asegúrate de configurar las reglas RLS (Row Level Security) en Supabase para proteger tu base de datos.
