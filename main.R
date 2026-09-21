# ==========================================
# ZOHO MULTI-REPORT CAPTURE & WHATSAPP AUTO-SHARE
# ==========================================

# --- 0. TIME GATE (08:00 AM to 10:10 PM IST) ---
Sys.setenv(TZ = "Asia/Kolkata")
current_time <- as.POSIXlt(Sys.time())
current_hour <- current_time$hour
current_min <- current_time$min

time_numeric <- current_hour + (current_min / 60)

if (time_numeric < 8.0 || time_numeric > (22 + 10/60)) {
  message(sprintf("Current time is %02d:%02d IST. Outside operating window (08:00 AM - 10:10 PM).", current_hour, current_min))
  message("Sleeping action. No reports will be generated.")
  quit(save = "no", status = 0)
}

# --- 1. DYNAMIC R PACKAGE INSTALLATION ---
required_packages <- c("reticulate", "httr", "jsonlite")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
    library(pkg, character.only = TRUE)
  }
}

# --- 2. CONFIGURATION ---
INSTANCE_ID <- "710722687085"
API_TOKEN <- "502764d8d4474e06aa0e3daada0c7fde6646e9ea53214d2bb8"
WHATSAPP_CHAT_ID <- "120363411226278041@g.us"

# --- 3. DYNAMIC PLAYWRIGHT SETUP ---
env_name <- "zoho_automation_env"
if (!virtualenv_exists(env_name)) {
  virtualenv_create(env_name)
  virtualenv_install(env_name, packages = c("playwright"))
  py_exe <- virtualenv_python(env_name)
  system2(py_exe, args = c("-m", "playwright", "install", "chromium"))
}
use_virtualenv(env_name, required = TRUE)

# --- 4. DYNAMIC DOWNLOADS FOLDER PATH TARGETING ---
downloads_folder <- file.path(Sys.getenv("USERPROFILE"), "Downloads")
if (!dir.exists(downloads_folder)) {
  downloads_folder <- file.path(Sys.getenv("HOME"), "Downloads")
}

# --- Reports Configuration ---
reports_config <- list(
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007446659197", 
    tab = "DAU", 
    title = "Hub Wise DAU 3.0", 
    filename = "1_hub_wise_dau.png"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007273104249", 
    tab = "Summary", 
    title = "Hub Wise Summary 3.0", 
    filename = "2_hub_wise_summary.png",
    sort_column = "Attempt%"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007275108264", 
    tab = "FASR",    
    title = "Hub wise - FASR 3.0", 
    filename = "3_overall_fasr.png",
    sort_column = "FASR"
  ),
  list(
    type = "custom_filter",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007275108264", 
    tab = "FASR",    
    title = "Hub wise - FASR 3.0", 
    filename = "4_ftpl_cod_fasr.png",
    client_tag = "FTPL",
    payment_mode = "COD",
    sort_column = "FASR"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007373618153", 
    tab = "FPSR",    
    title = "HUB wise- FPSR 3.0", 
    filename = "5_overall_fpsr.png",
    sort_column = "FPSR"
  ),
  list(
    type = "custom_filter",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007373618153", 
    tab = "FPSR",    
    title = "HUB wise- FPSR 3.0", 
    filename = "6_ftpl_fpsr.png",
    client = "FTPL",
    sort_column = "FPSR"
  ),
  list(
    type = "custom_filter",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007398452009", 
    tab = "C2",    
    title = "Hub Wise Summary 3.0 - C2", 
    filename = "7_c2_prepaid_fasr.png",
    payment_mode = "PREPAID",
    sort_column = "FASR" 
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007723086155", 
    tab = "Shipment Tally",    
    title = "Hub-Wise : Shipment Tally", 
    filename = "8_shipment_tally.png",
    sort_column = "Adherence %"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007446940689", 
    tab = "FOD",    
    title = "Hub Wise FOD 3.0", 
    filename = "9_hub_wise_fod.png"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000001470070/view/159245000016852015", 
    tab = "Network Load",    
    title = "Network load", 
    filename = "10_network_load.png",
    sort_column = "Total"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000286997288/view/159245007373476550",
    tab = "DSR",
    title = "Hub wise - DSR",
    filename = "11_hub_wise_dsr.png"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000001470070/view/159245005630148864",
    tab = "Hub Wise NC", 
    title = "Hub Wise NC",
    filename = "12_hub_wise_nc.png",
    sort_column = "hub"
  ),
  list(
    type = "standard",
    url = "https://analytics.zoho.in/workspace/159245000001470070/view/159245002188310288",
    tab = "Lead-Tracking-Dashboard", 
    title = "Hub-wise-leads",
    filename = "13_hub_wise_leads.png",
    sort_column = "Hub"
  )
)

# --- 5. CORE CAPTURE FUNCTION ---

capture_all_reports <- function() {
  message(sprintf("Target directory resolved to: %s", downloads_folder))
  message("Opening background browser to process reports locally...")
  
  cookie_data <- Sys.getenv("ZOHO_COOKIES")
  auth_file <- normalizePath(file.path(getwd(), "zoho_auth.json"), winslash = "/", mustWork = FALSE)
  
  if (nzchar(cookie_data)) {
    cookie_data <- gsub('"unspecified"', '"Lax"', cookie_data)
    cookie_data <- gsub('"no_restriction"', '"None"', cookie_data)
    cookie_data <- gsub('"strict"', '"Strict"', cookie_data)
    writeLines(cookie_data, auth_file)
    message("Successfully loaded Zoho Cookies from GitHub Secrets.")
  } else {
    message("WARNING: ZOHO_COOKIES secret is empty or missing!")
  }
  
  json_data_str <- as.character(jsonlite::toJSON(reports_config, auto_unbox = TRUE))
  target_dir_str <- normalizePath(downloads_folder, winslash = "/", mustWork = FALSE)
  
  py_script <- paste0("
import json
import os
import time
import traceback
from playwright.sync_api import sync_playwright

TARGET_DIR = r'''", target_dir_str, "'''
REPORTS_LIST = json.loads(r'''", json_data_str, "''')
AUTH_FILE = r'''", auth_file, "'''

captured_results = []

def process_reports():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--disable-blink-features=AutomationControlled']
        )
        
        context_args = {
            'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'viewport': {'width': 1920, 'height': 1080}
        }
        
        if os.path.exists(AUTH_FILE) and os.path.getsize(AUTH_FILE) > 0:
            context_args['storage_state'] = AUTH_FILE
            
        context = browser.new_context(**context_args)
        page = context.new_page()
        page.set_default_timeout(60000) 
        
        page.on('dialog', lambda dialog: dialog.accept())

        # -----------------------------------------------
        # 1. LEVEL 23 NATIVE PLAYWRIGHT SORTING
        # -----------------------------------------------
        def apply_sort(column_name):
            print(f\"\\n   -> Sorting on column: [ {column_name} ]\", flush=True)
            
            inject_css_js = '''() => {
                try {
                    let style = document.createElement('style');
                    style.innerHTML = \"*[class*='tooltip'], [id*='tooltip'], .lyteTooltip { display: none !important; opacity: 0 !important; pointer-events: none !important; } th svg, th i, th [class*='sort'], th [class*='icon'], .zdb-sort-icon { opacity: 1 !important; visibility: visible !important; display: inline-block !important; }\";
                    document.head.appendChild(style);
                } catch(e) {}
            }'''
            
            for f in page.frames:
                if not f.is_detached():
                    try: f.evaluate(inject_css_js)
                    except: pass

            target_clean = ''.join(e for e in column_name.lower() if e.isalnum())
            sorted_successfully = False
            
            # Active Polling Loop
            for attempt in range(15):
                for f in page.frames:
                    if f.is_detached(): continue
                    try:
                        headers = f.locator('th, [role=\"columnheader\"], td, div[class*=\"header\"], div[class*=\"Header\"]')
                        count = headers.count()
                        for i in range(count):
                            loc = headers.nth(i)
                            if loc.is_visible(timeout=100):
                                text = loc.inner_text()
                                clean_text = ''.join(e for e in text.lower() if e.isalnum())
                                if target_clean in clean_text and len(clean_text) > 0:
                                    if \"zero\" in clean_text and \"zero\" not in target_clean: continue
                                    if \"d2\" in clean_text and \"d2\" not in target_clean: continue
                                    if \"d6\" in clean_text and \"d6\" not in target_clean: continue
                                    
                                    loc.scroll_into_view_if_needed()
                                    
                                    # Hybrid JS Injection directly on the exact Playwright Node Reference
                                    loc.evaluate(\"\"\"el => {
                                        let rect = el.getBoundingClientRect();
                                        let targetX = rect.x + rect.width - 12;
                                        let targetY = rect.y + (rect.height / 2);
                                        let dropEl = document.elementFromPoint(targetX, targetY) || el;
                                        dropEl.dispatchEvent(new MouseEvent('mouseover', {bubbles:true}));
                                        dropEl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true}));
                                        dropEl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true}));
                                        dropEl.click();
                                    }\"\"\")
                                    sorted_successfully = True
                                    break
                    except: pass
                    if sorted_successfully: break
                if sorted_successfully: break
                time.sleep(2)
                
            if sorted_successfully:
                print(f\"      -> Success: Triggered sort natively inside frame.\", flush=True)
                time.sleep(2)
                for f in page.frames:
                    if f.is_detached(): continue
                    try:
                        popups = f.get_by_text(\"View Underlying Data\", exact=False)
                        if popups.count() > 0 and popups.first.is_visible(timeout=500):
                            popups.first.click(force=True)
                    except: pass
                time.sleep(10)
            else:
                print(f\"      [!] Warning: Could not locate column '{column_name}' for sorting after 30s.\", flush=True)

        # -----------------------------------------------
        # 2. LEVEL 23 NATIVE PLAYWRIGHT FILTERING
        # -----------------------------------------------
        def apply_filter(filter_label, filter_value):
            print(f\"\\n   -> Applying filter: [ {filter_label} ] -> [ {filter_value} ]\", flush=True)
            
            opened = False
            for attempt in range(15):
                for f in page.frames:
                    if f.is_detached(): continue
                    try:
                        # Native Playwright Accessibility Search completely pierces fragmented HTML tags
                        elements = f.get_by_text(filter_label, exact=False)
                        count = elements.count()
                        if count > 0:
                            loc = elements.nth(count - 1)
                            if loc.is_visible(timeout=500):
                                loc.scroll_into_view_if_needed()
                                loc.evaluate(\"\"\"el => {
                                    let rect = el.getBoundingClientRect();
                                    let targetX = rect.x + 15;
                                    let targetY = rect.y + 35;
                                    let dropEl = document.elementFromPoint(targetX, targetY) || el;
                                    dropEl.dispatchEvent(new MouseEvent('mouseover', {bubbles:true}));
                                    dropEl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true}));
                                    dropEl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true}));
                                    dropEl.click();
                                }\"\"\")
                                opened = True
                                break
                    except: pass
                if opened: break
                time.sleep(2)
                
            if not opened:
                print(f\"      [!] Warning: Could not locate filter label '{filter_label}' after 30s. Skipping.\", flush=True)
                return
                
            time.sleep(3)

            def click_popup_btn(btn_text):
                for _ in range(5):
                    for f in page.frames:
                        if f.is_detached(): continue
                        try:
                            locs = f.get_by_text(btn_text, exact=True)
                            if locs.count() > 0 and locs.first.is_visible(timeout=500):
                                locs.first.click(force=True)
                                return True
                        except: pass
                    time.sleep(1)
                return False

            print(\"      -> Clicking 'Clear' defaults...\", flush=True)
            if not click_popup_btn(\"Clear\"):
                click_popup_btn(\"Select None\")
            time.sleep(1)

            print(f\"      -> Typing '{filter_value}'...\", flush=True)
            page.keyboard.type(filter_value)
            time.sleep(2)

            print(f\"      -> Selecting '{filter_value}' box...\", flush=True)
            if not click_popup_btn(filter_value):
                page.keyboard.press(\"ArrowDown\")
                time.sleep(0.5)
                page.keyboard.press(\"Space\")
            time.sleep(1)

            print(\"      -> Clicking 'OK' to lock filter...\", flush=True)
            if not click_popup_btn(\"OK\"):
                if not click_popup_btn(\"Apply\"):
                    page.keyboard.press(\"Enter\")
            
            time.sleep(0.5)
            page.keyboard.press(\"Escape\") 
            print(\"      -> Waiting 10 seconds for dashboard data to reload...\", flush=True)
            time.sleep(10) 

        # -----------------------------------------------
        # THE FAIL-SAFE LOOP
        # -----------------------------------------------
        try:
            for idx, item in enumerate(REPORTS_LIST):
                try:
                    report_url = item['url']
                    tab_name = item['tab']
                    table_title = item['title']
                    filename = item['filename']
                    report_type = item.get('type', 'standard')

                    file_path = os.path.join(TARGET_DIR, filename)
                    print(f'\\n======================================================', flush=True)
                    print(f'--- [{idx+1}/{len(REPORTS_LIST)}] Loading Tab: \"{tab_name}\" | Saving to: \"{filename}\" ---', flush=True)

                    try: page.evaluate(\"window.onbeforeunload = null;\")
                    except: pass

                    page.goto(report_url, wait_until='domcontentloaded')
                    time.sleep(5)
                    
                    apply_filter('SZM:', 'Gursewak Singh')

                    if report_type == 'custom_filter':
                        if 'client_tag' in item: apply_filter('client_tags:', item['client_tag'])
                        if 'payment_mode' in item: apply_filter('payment_mode:', item['payment_mode'])
                        if 'client' in item: apply_filter('client:', item['client'])

                    if 'sort_column' in item:
                        apply_sort(item['sort_column'])
                        
                    time.sleep(5)

                    # -----------------------------------------------
                    # 3. LEVEL 23 NATIVE PLAYWRIGHT CROPPING ENGINE
                    # -----------------------------------------------
                    crop_box = None
                    for attempt in range(10): 
                        for f in page.frames:
                            if f.is_detached(): continue
                            try:
                                locs = f.get_by_text(table_title, exact=False)
                                if locs.count() > 0:
                                    loc = locs.first
                                    if loc.is_visible(timeout=500):
                                        loc.scroll_into_view_if_needed()
                                        
                                        raw_rect = loc.evaluate(\"\"\"el => {
                                            let container = el;
                                            let depth = 0;
                                            while (container && container.parentElement && depth < 30) {
                                                if (container.offsetHeight > 200 && container.offsetWidth > 400) {
                                                    let rect = container.getBoundingClientRect();
                                                    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
                                                }
                                                container = container.parentElement;
                                                depth++;
                                            }
                                            return null;
                                        }\"\"\")
                                        
                                        if raw_rect:
                                            offset_x = 0
                                            offset_y = 0
                                            if f != page.main_frame:
                                                try:
                                                    f_box = f.frame_element().bounding_box()
                                                    if f_box:
                                                        offset_x = f_box['x']
                                                        offset_y = f_box['y']
                                                except: pass
                                            
                                            vw = page.evaluate('window.innerWidth')
                                            vh = page.evaluate('window.innerHeight')
                                            x = max(0, raw_rect['x'] + offset_x)
                                            y = max(0, raw_rect['y'] + offset_y)
                                            width = min(raw_rect['width'], vw - x)
                                            height = min(raw_rect['height'], vh - y)
                                            
                                            crop_box = { 'x': x, 'y': y, 'width': width, 'height': height, 'valid': (height > 100 and width > 100) }
                                            break
                            except: pass
                        if crop_box: break
                        time.sleep(2)

                    if crop_box and crop_box['valid']:
                        page.screenshot(path=file_path, clip={'x': crop_box['x'], 'y': crop_box['y'], 'width': crop_box['width'], 'height': crop_box['height']}, timeout=25000)
                        status = f'CROPPED ({int(crop_box[\"width\"])})x({int(crop_box[\"height\"])})'
                    else:
                        page.screenshot(path=file_path, full_page=False, timeout=25000)
                        status = 'FULL VIEWPORT (Fallback)'

                    captured_results.append({
                        'index': idx + 1, 'tab': tab_name, 'title': table_title, 'file': filename, 'path': file_path, 'status': status
                    })
                    print(f'Saved to Downloads: {filename} -> {status}', flush=True)

                except Exception as e:
                    print(f'      [!] Report {idx+1} failed catastrophically: {e}', flush=True)
                    try: page.screenshot(path=file_path, full_page=False, timeout=25000)
                    except: pass
                    captured_results.append({
                        'index': idx + 1, 'tab': tab_name, 'title': table_title, 'file': filename, 'path': file_path, 'status': 'FAILED (Fallback)'
                    })
        finally:
            context.close()
            browser.close()

process_reports()
")
  
  py_run_string(py_script)
}

# --- 6. WHATSAPP SENDING FUNCTION ---
send_to_whatsapp <- function(file_path, title) {
  if (!nzchar(API_TOKEN) || !nzchar(WHATSAPP_CHAT_ID)) {
    message("   -> [SKIPPED] Missing WhatsApp API credentials.")
    return()
  }
  
  url <- sprintf("https://api.green-api.com/waInstance%s/sendFileByUpload/%s", INSTANCE_ID, API_TOKEN)
  caption_text <- sprintf("📊 *%s*", title)
  
  payload <- list(
    chatId = WHATSAPP_CHAT_ID,
    caption = caption_text,
    file = httr::upload_file(file_path)
  )
  
  message(sprintf("   -> Uploading %s to WhatsApp...", basename(file_path)))
  res <- httr::POST(url, body = payload, encode = "multipart")
  
  if (httr::status_code(res) == 200) {
    message("      [OK] Successfully sent to WhatsApp.")
  } else {
    message(sprintf("      [FAILED] HTTP %s", httr::status_code(res)))
    message(httr::content(res, "text", encoding = "UTF-8"))
  }
}

# --- 7. EXECUTION ---
job <- function() {
  message(sprintf("\n==========================================="))
  message(sprintf("STARTING REPORT CAPTURE AT %s", Sys.time()))
  message(sprintf("===========================================\n"))
  
  capture_all_reports()
  
  message("\n==========================================================================")
  message("                    WHATSAPP DISTRIBUTION SUMMARY                          ")
  message("==========================================================================")
  
  results <- py$captured_results
  
  if (!is.null(results) && length(results) > 0) {
    for (i in seq_along(results)) {
      item <- results[[i]]
      message(sprintf("\n[%d] Processing: %s", item$index, item$title))
      
      if (file.exists(item$path)) {
        send_to_whatsapp(item$path, item$title)
      } else {
        message("   -> [ERROR] File missing from Downloads folder. Cannot send.")
      }
    }
  } else {
    message("No reports were generated.")
  }
  
  message("\n==========================================================================")
  message(sprintf("Capture and Distribution Cycle Complete at %s.", Sys.time()))
}

job()
