# Radar Kochala (Reporta Cochabamba) 🎯

Aplicación móvil desarrollada en Flutter y Supabase para la gestión de incidentes urbanos y baches en la ciudad de Cochabamba, Bolivia. 

Incluye validación fotográfica mediante Inteligencia Artificial (Gemini), persistencia offline (SharedPreferences), paneles de control administrativo para operadores y un sistema de gamificación comunitaria.

## ✨ Características Principales

*   **Reportes Georreferenciados:** Restringido a las coordenadas exactas de Cochabamba.
*   **Validación de Inteligencia Artificial (Anti-Spam):** Gemini analiza la imagen del bache o incidente y genera un nivel de confianza (is_ai_verified), con popups dinámicos para guiar al ciudadano.
*   **Modo Offline Resiliente:** Si el usuario no tiene internet, los reportes se encolan y se sincronizan silenciosamente en segundo plano al recuperar la conexión.
*   **Paginación Infinita y Mapas en Vivo:** Manejo eficiente de memoria en el *Dashboard* del operador mediante lazy-loading de reportes, tanto en listas como en mapas de calor interactivos.
*   **Gamificación y Ranking Comunitario:** Los usuarios ganan puntos cuando sus reportes son validados y solucionados por la alcaldía.
*   **Optimizaciń de Imágenes:** Compresión nativa en la captura para ahorro de ancho de banda.

---

## 🚀 Configuración (Setup)

Para correr este proyecto en tu propia máquina, necesitas configurar tus propias claves de API de **Supabase** (Base de Datos / Autenticación) y **Google Gemini** (Inteligencia Artificial).

1. Clona el repositorio:
   \\ash
   git clone https://github.com/Marce0c0/Radar-Kochala.git
   cd Radar-Kochala
   \
2. Instala las dependencias:
   \\ash
   flutter pub get
   \
3. **Configura las variables de entorno:**
   - En la raíz del proyecto encontrarás un archivo llamado .env.example.
   - Renómbralo o cópialo para crear un nuevo archivo llamado exactamente .env.
   - Abre el archivo .env y pega tus claves de Supabase y Gemini:
     \\nv
     # Claves de Supabase (Obligatorias)
     SUPABASE_URL=tu_url_de_supabase_aqui
     SUPABASE_ANON_KEY=tu_anon_key_de_supabase_aqui

     # Clave de Gemini AI (Opcional, para verificación inteligente)
     GEMINI_API_KEY=tu_api_key_de_gemini_aqui
     \
4. **Sincroniza la Base de Datos:**
   Asegúrate de haber ejecutado todos los scripts de configuración SQL en el editor de tu proyecto en Supabase para tener las tablas de reportes, perfiles, votos, asignaciones y los buckets de almacenamiento configurados.

5. Ejecuta la aplicación:
   \\ash
   flutter run
   \
## 🔒 Notas de Seguridad
* Nunca subas tu archivo .env a GitHub. Ya está ignorado por defecto en el .gitignore.
* Asegúrate de configurar las reglas RLS (Row Level Security) en Supabase para proteger tu base de datos.
