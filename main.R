# ==========================================
# ZOHO MULTI-REPORT CAPTURE & WHATSAPP AUTO-SHARE
# ==========================================

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
# Pulling sensitive tokens securely from GitHub Actions Environments
API_TOKEN <- Sys.getenv("ZOHO_API_TOKEN")
WHATSAPP_CHAT_ID <- Sys.getenv("WHATSAPP_CHAT_ID")

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
        page.set_default_timeout(45000)
        
        page.on('dialog', lambda dialog: dialog.accept())

        # -----------------------------------------------
        # 1. XPATH FAST SORTING
        # -----------------------------------------------
        def apply_sort(column_name):
            print(f\"\\n   -> Sorting on column: [ {column_name} ]\", flush=True)
            
            inject_css_js = r'''() => {
                let style = document.createElement('style');
                style.innerHTML = \"*[class*='tooltip'], [id*='tooltip'], .lyteTooltip { display: none !important; opacity: 0 !important; pointer-events: none !important; } th svg, th i, th [class*='sort'], th [class*='icon'], .zdb-sort-icon { opacity: 1 !important; visibility: visible !important; display: inline-block !important; }\";
                document.head.appendChild(style);
            }'''
            
            try: page.evaluate(inject_css_js)
            except: pass
            for fr in page.frames:
                try: fr.evaluate(inject_css_js)
                except: pass

            sort_js = r'''(colName) => {
                let cleanName = colName.toLowerCase().split(' ').join('');
                let els = Array.from(document.querySelectorAll('th, [role=\"columnheader\"], td[class*=\"header\"]'));
                for (let el of els) {
                    let rect = el.getBoundingClientRect();
                    if (rect.height > 10 && rect.width > 20 && rect.y > 45) {
                        let text = (el.getAttribute('title') || '') + ' ' + (el.innerText || '');
                        let cleanText = text.toLowerCase().split(' ').join('');
                        
                        let match = false;
                        if (cleanText.includes(cleanName)) {
                            if (cleanText.includes('zero') && !cleanName.includes('zero')) match = false;
                            else if (cleanText.includes('d2') && !cleanName.includes('d2')) match = false;
                            else if (cleanText.includes('d6') && !cleanName.includes('d6')) match = false;
                            else match = true;
                        } else if (cleanText.length >= 5 && cleanText.startsWith(cleanName)) {
                            match = true;
                        }
                        
                        if (match) {
                            el.scrollIntoView({behavior: 'instant', block: 'center'});
                            let icon = el.querySelector('svg, i, span[class*=\"icon\"], span[class*=\"sort\"], span[class*=\"arrow\"]');
                            if (icon) {
                                icon.scrollIntoView({behavior: 'instant', block: 'center'});
                                icon.click();
                                return 'icon_clicked';
                            } else {
                                el.click();
                                return 'th_clicked';
                            }
                        }
                    }
                }
                return 'not_found';
            }'''

            sorted_successfully = False
            for f in [page] + page.frames:
                if sorted_successfully: break
                try:
                    res = f.evaluate(sort_js, column_name)
                    if res in ['icon_clicked', 'th_clicked']:
                        print(f\"      -> Success: Javascript forcefully executed sort action ({res}).\", flush=True)
                        sorted_successfully = True
                        
                        page.wait_for_timeout(1000)
                        dismiss_js = r'''() => {
                            try {
                                let iter = document.evaluate('//*[text()=\"View Underlying Data\"]', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                                if (iter.snapshotLength > 0) iter.snapshotItem(0).click();
                            } catch(e){}
                        }'''
                        try: f.evaluate(dismiss_js)
                        except: pass
                        
                        page.wait_for_timeout(10000)
                        break
                except Exception as e:
                    pass
            
            if not sorted_successfully:
                print(f\"      [!] Error: Javascript could not locate column '{column_name}' for sorting.\", flush=True)

        # -----------------------------------------------
        # 2. ULTRA-FAST XPATH FILTERING 
        # -----------------------------------------------
        def apply_filter(filter_label, filter_value):
            print(f\"\\n   -> Applying filter: [ {filter_label} ] -> [ {filter_value} ]\", flush=True)
            
            open_filter_js = r'''(label) => {
                try {
                    let iter = document.evaluate('//*[contains(text(), \"' + label + '\")]', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                    for (let i = iter.snapshotLength - 1; i >= 0; i--) {
                        let el = iter.snapshotItem(i);
                        let rect = el.getBoundingClientRect();
                        if (rect.height > 0 && rect.width > 0) {
                            el.scrollIntoView({behavior: 'instant', block: 'center'});
                            let targetX = rect.x + 15;
                            let targetY = rect.y + 35;
                            let dropEl = document.elementFromPoint(targetX, targetY) || el;
                            dropEl.click();
                            dropEl.dispatchEvent(new MouseEvent('mousedown', {bubbles:true}));
                            dropEl.dispatchEvent(new MouseEvent('mouseup', {bubbles:true}));
                            return true;
                        }
                    }
                } catch(e){}
                return false;
            }'''
            
            opened = False
            for f in [page] + page.frames:
                if opened: break
                try:
                    if f.evaluate(open_filter_js, filter_label):
                        opened = True
                except: pass
                
            if not opened:
                print(f\"      [!] Error: Could not locate filter label '{filter_label}'\", flush=True)
                return
                
            page.wait_for_timeout(2500)

            def click_popup_btn(btn_text):
                click_btn_js = r'''(text) => {
                    try {
                        let iter = document.evaluate('//*[text()=\"' + text + '\"]', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                        for (let i = iter.snapshotLength - 1; i >= 0; i--) {
                            let el = iter.snapshotItem(i);
                            if (el.getBoundingClientRect().height > 0) {
                                el.click();
                                return true;
                            }
                        }
                    } catch(e){}
                    return false;
                }'''
                
                for f in [page] + page.frames:
                    try:
                        if f.evaluate(click_btn_js, btn_text):
                            return True
                    except: pass
                return False

            print(\"      -> Clicking 'Clear' defaults...\", flush=True)
            if not click_popup_btn(\"Clear\"):
                click_popup_btn(\"Select None\")
            page.wait_for_timeout(1000)

            print(f\"      -> Typing '{filter_value}'...\", flush=True)
            page.keyboard.type(filter_value)
            page.wait_for_timeout(1500)

            print(f\"      -> Selecting '{filter_value}' box...\", flush=True)
            if not click_popup_btn(filter_value):
                page.keyboard.press(\"ArrowDown\")
                page.wait_for_timeout(500)
                page.keyboard.press(\"Space\")
            page.wait_for_timeout(1000)

            print(\"      -> Clicking 'OK' to lock filter...\", flush=True)
            if not click_popup_btn(\"OK\"):
                if not click_popup_btn(\"Apply\"):
                    page.keyboard.press(\"Enter\")
            
            page.wait_for_timeout(500)
            page.keyboard.press(\"Escape\") 
            print(\"      -> Waiting 10 seconds for dashboard data to reload...\", flush=True)
            page.wait_for_timeout(10000) 

        try:
            for idx, item in enumerate(REPORTS_LIST):
                report_url = item['url']
                tab_name = item['tab']
                table_title = item['title']
                filename = item['filename']
                report_type = item.get('type', 'standard')

                file_path = os.path.join(TARGET_DIR, filename)
                print(f'\\n--- [{idx+1}/{len(REPORTS_LIST)}] Loading Tab: \"{tab_name}\" | Saving to: \"{filename}\" ---', flush=True)

                # --- INSTANTLY KILL 'UNSAVED CHANGES' ZOHO POPUPS ---
                try: page.evaluate(\"window.onbeforeunload = null;\")
                except: pass

                page.goto(report_url, wait_until='domcontentloaded')
                page.wait_for_timeout(15000) 
                
                apply_filter('SZM:', 'Gursewak Singh')

                if report_type == 'custom_filter':
                    if 'client_tag' in item: apply_filter('client_tags:', item['client_tag'])
                    if 'payment_mode' in item: apply_filter('payment_mode:', item['payment_mode'])
                    if 'client' in item: apply_filter('client:', item['client'])

                if 'sort_column' in item:
                    apply_sort(item['sort_column'])
                    
                page.wait_for_timeout(5000)

                # -----------------------------------------------
                # 3. STRICT SIZE-AWARE CROPPING ENGINE (XPATH)
                # -----------------------------------------------
                find_and_scroll_js = r'''(title) => {
                    try {
                        let iter = document.evaluate('//*[contains(text(), \"' + title + '\")]', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                        let matches = [];
                        for(let i=0; i<iter.snapshotLength; i++) {
                            let el = iter.snapshotItem(i);
                            if(el.offsetHeight > 0) matches.push(el);
                        }
                        matches.sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y);
                        for (let match of matches) {
                            let container = match;
                            while (container && container.parentElement) {
                                if (container.offsetHeight > 200 && container.offsetWidth > 400) {
                                    container.scrollIntoView({behavior: 'instant', block: 'center'});
                                    return true;
                                }
                                container = container.parentElement;
                            }
                        }
                    } catch(e){}
                    return false;
                }'''
                
                for f in [page] + page.frames:
                    try:
                        if f.evaluate(find_and_scroll_js, table_title): break
                    except: pass
                
                page.wait_for_timeout(3000)

                find_and_crop_js = r'''(title) => {
                    try {
                        let iter = document.evaluate('//*[contains(text(), \"' + title + '\")]', document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                        let matches = [];
                        for(let i=0; i<iter.snapshotLength; i++) {
                            let el = iter.snapshotItem(i);
                            if(el.offsetHeight > 0) matches.push(el);
                        }
                        matches.sort((a, b) => a.getBoundingClientRect().y - b.getBoundingClientRect().y);
                        for (let match of matches) {
                            let container = match;
                            while (container && container.parentElement) {
                                if (container.offsetHeight > 200 && container.offsetWidth > 400) {
                                    let rect = container.getBoundingClientRect();
                                    return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
                                }
                                container = container.parentElement;
                            }
                        }
                    } catch(e){}
                    return null;
                }'''

                crop_box = None
                for f in [page] + page.frames:
                    try:
                        raw_rect = f.evaluate(find_and_crop_js, table_title)
                        if raw_rect:
                            offset_x = 0
                            offset_y = 0
                            
                            if f != page and f != page.main_frame:
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

                if crop_box and crop_box['valid']:
                    page.screenshot(path=file_path, clip={'x': crop_box['x'], 'y': crop_box['y'], 'width': crop_box['width'], 'height': crop_box['height']})
                    status = f'CROPPED ({int(crop_box[\"width\"])})x({int(crop_box[\"height\"])})'
                else:
                    page.screenshot(path=file_path, full_page=False)
                    status = 'FULL VIEWPORT (Fallback)'

                captured_results.append({
                    'index': idx + 1, 'tab': tab_name, 'title': table_title, 'file': filename, 'path': file_path, 'status': status
                })
                print(f'Saved to Downloads: {filename} -> {status}', flush=True)

        except Exception as e:
            print('An error occurred during execution...', flush=True)
            traceback.print_exc()

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
    message("   -> [SKIPPED] Missing WhatsApp API credentials in GitHub Secrets.")
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
