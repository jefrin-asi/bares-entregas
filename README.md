# Entregas del Sistema Bares (archivos cifrados)

Los paquetes están en **Releases**, cifrados. La clave no está en este repositorio: la pide el instalador.

**Windows** (PowerShell como administrador, en la PC servidor):
```powershell
irm https://raw.githubusercontent.com/jefrin-asi/bares-entregas/main/instalar-bares.ps1 | iex
```

**Ubuntu**:
```bash
curl -fsSL https://raw.githubusercontent.com/jefrin-asi/bares-entregas/main/instalar-bares.sh -o instalar-bares.sh && bash instalar-bares.sh
```
Muestra en una PC que ya tiene otro sistema: `bash instalar-bares.sh --muestra`

El mismo comando instala la primera vez y actualiza después, con respaldo previo y regreso automático a la versión anterior si algo falla.
