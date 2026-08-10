## AI Agent (Tool Calling)

### Fitur Baru
- **16 universal tools**: get_products, get_customers, get_summary, get_low_stock, get_transactions, get_top_products, get_promos, get_employees, get_attendance, get_expenses, get_debts, get_suppliers, search_product, search_customer, get_monthly_summary, navigate_to
- **Domain-specific tools**: Laundry (3), F&B (2), Bengkel/Servis (1), Salon (1), Apotek (1), Fotocopy (1)
- **Agent loop**: AI otomatis panggil tools, Flutter execute, kirim hasil balik ke AI — sampai dapat jawaban final
- **Thinking UX**: Indikator di bubble chat ("Menganalisa..." / "Menjalankan: get_products...")

### AI Chat UI
- **Drawer overlay fix**: Session drawer sekarang overlay (Stack) — chat tidak menciut
- **Animated drawer**: Slide dari kiri + backdrop semi-transparan
- **Bubble upgrade**: Timestamp di bawah, spacing lebih rapi, hint chips restyle
- **Header upgrade**: Ikon AI + status aktif

### Toko Online
- **Unhide di 4 varian**: Laundry, Bengkel, Salon, Fotocopy sekarang bisa akses Toko Online
- **Dashboard spacing fix**: Pill bar laundry stats proporsional

### Tech
- Supabase Edge Function ai-assistant upgraded — support tool calling (Groq tool_choice: auto)
- AiService + AgentToolRegistry — reusable, variant-aware

### Build
- APK: release (102.6 MB) — NUSA_DEV=true
- Build: 40
- Version: 2.0.0-dev
