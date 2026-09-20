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
        page.set_default_timeout(60000) 
        
        page.on('dialog', lambda dialog: dialog.accept())

        # -----------------------------------------------
        # 1. PURE V8 SORTING (BYPASSES IPC BOTTLENECK)
        # -----------------------------------------------
        def apply_sort(column_name):
            print(f\"\\n   -> Sorting on column: [ {column_name} ]\", flush=True)
            
            inject_css_js = r'''() => {
                function scan(win) {
                    try {
                        let style = win.document.createElement('style');
                        style.innerHTML = \"*[class*='tooltip'], [id*='tooltip'], .lyteTooltip { display: none !important; opacity: 0 !important; pointer-events: none !important; } th svg, th i, th [class*='sort'], th [class*='icon'], .zdb-sort-icon { opacity: 1 !important; visibility: visible !important; display: inline-block !important; }\";
                        win.document.head.appendChild(style);
                        for(let i=0; i<win.frames.length; i++) scan(win.frames[i]);
                    } catch(e) {}
                }
                scan(window);
            }'''
            try: page.evaluate(inject_css_js)
            except: pass

            sort_js = '''(colName) => {
                let cleanName = colName.toLowerCase().split(' ').join('');
                function scan(win) {
                    try {
                        let els = Array.from(win.document.querySelectorAll('th, [role=\"columnheader\"], td[class*=\"header\"]'));
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
                                        return true;
                                    } else {
                                        el.click();
                                        return true;
                                    }
                                }
                            }
                        }
                        for (let i = 0; i < win.frames.length; i++) {
                            if (scan(win.frames[i])) return true;
                        }
                    } catch(e) {}
                    return false;
                }
                return scan(window);
            }'''

            try:
                if page.evaluate(sort_js, column_name):
                    print(f\"      -> Success: Javascript forcefully executed sort action.\", flush=True)
                    page.wait_for_timeout(1500)
                    dismiss_js = r'''() => {
                        function scan(win) {
                            try {
                                let iter = win.document.evaluate('//*[text()=\"View Underlying Data\"]', win.document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                                if (iter.snapshotLength > 0) { iter.snapshotItem(0).click(); return true; }
                                for (let i = 0; i < win.frames.length; i++) if (scan(win.frames[i])) return true;
                            } catch(e){}
                            return false;
                        }
                        scan(window);
                    }'''
                    try: page.evaluate(dismiss_js)
                    except: pass
                    page.wait_for_timeout(10000)
                else:
                    print(f\"      [!] Warning: Could not locate column '{column_name}' for sorting.\", flush=True)
            except Exception as e:
                pass


        # -----------------------------------------------
        # 2. PURE V8 FILTERING 
        # -----------------------------------------------
        def apply_filter(filter_label, filter_value):
            print(f\"\\n   -> Applying filter: [ {filter_label} ] -> [ {filter_value} ]\", flush=True)
            
            open_filter_js = '''(label) => {
                function scan(win) {
                    try {
                        let iter = win.document.evaluate('//*[contains(text(), \"' + label + '\")]', win.document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                        for (let i = iter.snapshotLength - 1; i >= 0; i--) {
                            let el = iter.snapshotItem(i);
                            let rect = el.getBoundingClientRect();
                            if (rect.height > 0 && rect.width > 0) {
                                el.scrollIntoView({behavior: 'instant', block: 'center'});
                                el.click();
                                return true;
                            }
                        }
                        for (let i = 0; i < win.frames.length; i++) {
                            if (scan(win.frames[i])) return true;
                        }
                    } catch(e){}
                    return false;
                }
                return scan(window);
            }'''
            
            try:
                if not page.evaluate(open_filter_js, filter_label):
                    print(f\"      [!] Warning: Could not locate filter label '{filter_label}'. Skipping.\", flush=True)
                    return
            except Exception as e: 
                return
                
            page.wait_for_timeout(2500)

            def click_popup_btn(btn_text):
                click_btn_js = '''(text) => {
                    function scan(win) {
                        try {
                            let iter = win.document.evaluate('//*[text()=\"' + text + '\"]', win.document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
                            for (let i = iter.snapshotLength - 1; i >= 0; i--) {
                                let el = iter.snapshotItem(i);
                                if (el.getBoundingClientRect().height > 0) {
                                    el.click();
                                    return true;
                                }
                            }
                            for (let i = 0; i < win.frames.length; i++) {
                                if (scan(win.frames[i])) return true;
                            }
                        } catch(e){}
                        return false;
                    }
                    return scan(window);
                }'''
                try: return page.evaluate(click_btn_js, btn_text)
                except: return False

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
                    # 3. PURE V8 SIZE-AWARE CROPPING ENGINE
                    # -----------------------------------------------
                    find_and_crop_js = '''(title) => {
                        function scan(win, offsetX, offsetY) {
                            try {
                                let iter = win.document.evaluate('//*[contains(text(), \"' + title + '\")]', win.document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
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
                                            let rect = container.getBoundingClientRect();
                                            return { x: rect.x + offsetX, y: rect.y + offsetY, width: rect.width, height: rect.height };
                                        }
                                        container = container.parentElement;
                                    }
                                }
                                
                                let iframes = win.document.querySelectorAll('iframe');
                                for(let i = 0; i < iframes.length; i++) {
                                    let rect = iframes[i].getBoundingClientRect();
                                    let res = scan(win.frames[i], offsetX + rect.x, offsetY + rect.y);
                                    if (res) return res;
                                }
                            } catch(e){}
                            return null;
                        }
                        return scan(window, 0, 0);
                    }'''

                    try:
                        crop_box = page.evaluate(find_and_crop_js, table_title)
                        if crop_box and crop_box['height'] > 100 and crop_box['width'] > 100:
                            vw = page.evaluate('window.innerWidth')
                            vh = page.evaluate('window.innerHeight')
                            cx = max(0, crop_box['x'])
                            cy = max(0, crop_box['y'])
                            cw = min(crop_box['width'], vw - cx)
                            ch = min(crop_box['height'], vh - cy)
                            page.screenshot(path=file_path, clip={'x': cx, 'y': cy, 'width': cw, 'height': ch})
                            status = f'CROPPED ({int(cw)})x({int(ch)})'
                        else:
                            page.screenshot(path=file_path, full_page=False)
                            status = 'FULL VIEWPORT (Fallback)'
                    except Exception as e:
                        page.screenshot(path=file_path, full_page=False)
                        status = 'FULL VIEWPORT (Fallback)'

                    captured_results.append({
                        'index': idx + 1, 'tab': tab_name, 'title': table_title, 'file': filename, 'path': file_path, 'status': status
                    })
                    print(f'Saved to Downloads: {filename} -> {status}', flush=True)

                except Exception as e:
                    print(f'      [!] Report {idx+1} failed catastrophically: {e}', flush=True)
                    try: page.screenshot(path=file_path, full_page=False)
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
