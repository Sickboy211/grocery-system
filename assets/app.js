// Barcode scanners act like keyboards: focus this field, scan, and the code is entered.
document.addEventListener('DOMContentLoaded',()=>{const code=document.getElementById('product-code');if(code&&location.hash==='#product-form')code.focus();});
