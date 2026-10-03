
## 🚀 Últimas Actualizaciones (Octubre 2026)

Se han implementado mejoras críticas en la estabilidad, datos de prueba y experiencia de usuario:

- **Saneamiento de Base de Datos:** Limpieza de cuentas fantasma y estandarización del esquema de Autenticación de Supabase (GoTrue) para permitir la creación masiva de cuentas sin romper el login.
- **Población de Datos Realistas:**
  - Creación de **20 cuentas de ciudadanos** con nombres completos reales y puntos de ranking.
  - Creación de **30 cuentas de trabajadores de campo** vinculadas correctamente al dominio institucional `@alcaldia.cbba`.
  - Inyección de **25 reportes de prueba** totalmente realistas (con imágenes representativas de baches, luminarias, basura, etc. vía `loremflickr`), distribuidos entre los mejores ciudadanos y en estados pendientes/en proceso (listos para ser gestionados).
- **Mejoras UI/UX:** 
  - Título del ranking actualizado a "Top 20 Usuarios Contribuyentes Anuales".
  - Se ha integrado un *Loader* (Animación de carga HTML/CSS puro) en `index.html` para eliminar la pantalla blanca durante el arranque inicial en la versión Web.

---

## 🔑 Credenciales de Prueba

Para probar la plataforma en todos sus niveles (especialmente en la versión desplegada), puedes utilizar las siguientes cuentas de prueba. 

**Contraseña universal para TODAS las cuentas:** `admin123`

### Administración y Control
| Rol | Correo de Acceso | Descripción |
| :--- | :--- | :--- |
| **Administrador** | `admin@alcaldia.cbba` | Panel de control total, creación de personal y estadísticas. |
| **Operador** | `operador@alcaldia.cbba` | Verificación de reportes ciudadanos, mapa de calor y control de estados. |

### Trabajadores de Campo
Tienen acceso a la aplicación móvil para ver el mapa de casos pendientes, atender reportes y subir fotos de resolución (el flujo de reparación). Puedes usar cualquiera de estas 3 cuentas:
| Rol | Correo de Acceso | Contraseña |
| :--- | :--- | :--- |
| **Trabajador 1** | `trabajador1.juan_perez@alcaldia.cbba` | `admin123` |
| **Trabajador 2** | `trabajador2.maria_mamani@alcaldia.cbba` | `admin123` |
| **Trabajador 3** | `trabajador3.carlos_condori@alcaldia.cbba` | `admin123` |

### Ciudadanos
Tienen acceso a la app para crear nuevos reportes, ver el mapa público y participar en el ranking de puntos. Puedes usar cualquiera de estas 3 cuentas que ya tienen puntos acumulados e historial:
| Rol | Correo de Acceso | Contraseña |
| :--- | :--- | :--- |
| **Ciudadano 1** | `diego.salinas@gmail.com` | `admin123` |
| **Ciudadano 2** | `lucia.valverde@gmail.com` | `admin123` |
| **Ciudadano 3** | `mateo.vargas@yahoo.com` | `admin123` |
