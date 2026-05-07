// web/flutter_bootstrap.js
{{flutter_js}}
{{flutter_build_config}}

// إنشاء عنصر تحميل
const loadingDiv = document.createElement('div');
loadingDiv.style.position = 'fixed';
loadingDiv.style.top = '50%';
loadingDiv.style.left = '50%';
loadingDiv.style.transform = 'translate(-50%, -50%)';
loadingDiv.style.textAlign = 'center';
loadingDiv.style.zIndex = '9999';
loadingDiv.innerHTML = `
  <div style="
    width: 50px;
    height: 50px;
    border: 4px solid #f3f3f3;
    border-top: 4px solid #4CAF50;
    border-radius: 50%;
    animation: spin 1s linear infinite;
    margin: 0 auto;
  "></div>
  <style>
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
  </style>
  <p style="margin-top: 16px; font-family: sans-serif;">جاري تحميل التطبيق...</p>
`;
document.body.appendChild(loadingDiv);

// تحميل التطبيق
_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    loadingDiv.innerHTML = '<p>جاري تهيئة المحرك...</p>';
    
    const appRunner = await engineInitializer.initializeEngine();
    
    loadingDiv.innerHTML = '<p>جاري تشغيل التطبيق...</p>';
    await appRunner.runApp();
    
    // إزالة مؤشر التحميل بعد ثانية
    setTimeout(() => {
      loadingDiv.style.opacity = '0';
      setTimeout(() => {
        if (loadingDiv.parentNode) {
          loadingDiv.parentNode.removeChild(loadingDiv);
        }
      }, 500);
    }, 1000);
  }
});