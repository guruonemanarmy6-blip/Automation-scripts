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
    url = "https://analytics.zoho.in/open-view/159245006990240760",
    tab = "DSR",
    title = "Hub wise - DSR",
    filename = "11_hub_wise_dsr.png"
  )
)

# --- 5. CORE CAPTURE FUNCTION ---

capture_all_reports <- function() {
  message(sprintf("Target directory resolved to: %s", downloads_folder))
  message("Opening background browser to process reports locally...")
  
  json_data_str <- as.character(jsonlite::toJSON(reports_config, auto_unbox = TRUE))
  user_dir_str <- normalizePath(file.path(getwd(), "zoho_r_session"), winslash = "/", mustWork = FALSE)
  target_dir_str <- normalizePath(downloads_folder, winslash = "/", mustWork = FALSE)
  
  py_script <- paste0("
import json
import time
import os
import traceback
from playwright.sync_api import sync_playwright

USER_DATA_DIR = r'''", user_dir_str, "'''
TARGET_DIR = r'''", target_dir_str, "'''
REPORTS_LIST = json.loads(r'''", json_data_str, "''')

captured_results = []

def process_reports():
    with sync_playwright() as p:
        context = p.chromium.launch_persistent_context(
            user_data_dir=USER_DATA_DIR,
            headless=True,
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            args=['--disable-blink-features=AutomationControlled'],
            viewport={'width': 1920, 'height': 1080}
        )
        page = context.new_page()
        page.set_default_timeout(45000)

        # -----------------------------------------------
        # 1. TAB NAVIGATION LOGIC (STRICT TOP-HEADER)
        # -----------------------------------------------
        def click_dashboard_tab(target_tab_name):
            print(f\"\\n   -> Forcing navigation to tab: [ {target_tab_name} ]...\")
            try:
                time.sleep(4)
                clicked = False
                
                # Iterate over ALL frames to handle Zoho 'open-view' links properly
                for f in [page] + page.frames:
                    if clicked: break
                    try:
                        clicked = f.evaluate(f'''(tabName) => {{
                            let els = Array.from(document.querySelectorAll('*'));
                            for(let el of els) {{
                                if(el.textContent && el.textContent.trim() === tabName) {{
                                    let rect = el.getBoundingClientRect();
                                    if(rect.y >= 0 && rect.y < 250 && rect.height > 10) {{
                                        el.click();
                                        return true;
                                    }}
                                }}
                            }}
                            return false;
                        }}''', target_tab_name)
                    except: pass
                
                if clicked:
                    print(f\"      -> Success: Clicked dashboard tab '{target_tab_name}'\")
                    time.sleep(12) 
                else:
                    for f in [page] + page.frames:
                        if clicked: break
                        try:
                            tabs = f.locator(f\"text='{target_tab_name}'\")
                            for i in range(tabs.count()):
                                box = tabs.nth(i).bounding_box()
                                if box and box['y'] < 250:
                                    tabs.nth(i).click(force=True)
                                    print(f\"      -> Success: Clicked dashboard tab '{target_tab_name}' (Fallback)\")
                                    time.sleep(12)
                                    clicked = True
                                    break
                        except: pass
            except Exception as e:
                pass


        # -----------------------------------------------
        # COLLISION-PROOF SORTING LOGIC
        # -----------------------------------------------
        def apply_sort(column_name):
            print(f\"\\n   -> Sorting on column: [ {column_name} ]\")
            
            css = '''
            *[class*='tooltip'], [id*='tooltip'], .lyteTooltip { display: none !important; opacity: 0 !important; pointer-events: none !important; }
            th svg, th i, th [class*='sort'], th [class*='icon'], .zdb-sort-icon { opacity: 1 !important; visibility: visible !important; display: inline-block !important; }
            '''
            page.add_style_tag(content=css)
            for fr in page.frames:
                try: fr.add_style_tag(content=css)
                except: pass

            target_clean = column_name.lower().replace(' ', '')
            sorted_successfully = False

            for f in [page] + page.frames:
                if sorted_successfully: break
                try:
                    headers = f.locator('th, [role=\"columnheader\"], td[class*=\"header\"]')
                    for i in range(headers.count()):
                        th = headers.nth(i)
                        if th.is_visible():
                            box = th.bounding_box()
                            if box and box['y'] > 45 and box['height'] > 10 and box['width'] > 20:
                                raw_text = str(th.get_attribute('title') or '') + \" \" + str(th.inner_text() or '')
                                actual_clean = ''.join(raw_text.split()).lower()
                                
                                match = False
                                if target_clean in actual_clean:
                                    if \"zero\" in actual_clean and \"zero\" not in target_clean: match = False
                                    elif \"d2\" in actual_clean and \"d2\" not in target_clean: match = False
                                    elif \"d6\" in actual_clean and \"d6\" not in target_clean: match = False
                                    else: match = True
                                elif len(actual_clean) >= 5 and target_clean.startswith(actual_clean):
                                    match = True
                                    
                                if match:
                                    th.scroll_into_view_if_needed()
                                    time.sleep(1)
                                    box = th.bounding_box()
                                    th.hover(force=True)
                                    time.sleep(1)
                                    
                                    icon_clicked = False
                                    icons = th.locator('svg, i, span[class*=\"icon\"], span[class*=\"sort\"], span[class*=\"arrow\"]')
                                    for j in range(icons.count() - 1, -1, -1):
                                        icon = icons.nth(j)
                                        ibox = icon.bounding_box()
                                        if ibox and ibox['width'] > 0:
                                            icon.click(force=True)
                                            icon_clicked = True
                                            print(\"      -> Success: Clicked the sort arrow icon directly.\")
                                            break
                                            
                                    if not icon_clicked:
                                        th.click(position={'x': box['width'] - 6, 'y': 6}, force=True)
                                        print(\"      -> Success: Clicked absolute Top-Right corner fallback.\")
                                        
                                    time.sleep(1.5)
                                    popup = f.locator(\"text='View Underlying Data'\")
                                    if popup.count() > 0 and popup.first.is_visible():
                                        page.keyboard.press(\"Escape\")
                                        time.sleep(1)
                                        th.click(position={'x': box['width'] - 4, 'y': 4}, force=True)

                                    sorted_successfully = True
                                    time.sleep(12) 
                                    break
                except Exception as e:
                    pass
            
            if not sorted_successfully:
                print(f\"      [!] Error: Could not locate a VISIBLE column '{column_name}' for sorting.\")


        def apply_filter(filter_label, filter_value):
            print(f\"\\n   -> Applying filter: [ {filter_label} ] -> [ {filter_value} ]\")
            opened = False
            for f in [page] + page.frames:
                try:
                    xpath = f\"//*[contains(text(), '{filter_label}')]\"
                    elements = f.locator(xpath)
                    for i in range(elements.count() - 1, -1, -1):
                        el = elements.nth(i)
                        if el.is_visible():
                            el.scroll_into_view_if_needed()
                            el.click(position={'x': 15, 'y': 35}, force=True)
                            opened = True
                            break
                except: pass
                if opened: break
                
            if not opened:
                print(f\"      [!] Error: Could not locate filter label '{filter_label}'\")
                return
                
            time.sleep(2.5)

            def click_popup_btn(btn_text):
                for f in [page] + page.frames:
                    try:
                        elements = f.locator(f\"text=\\\"{btn_text}\\\"\")
                        for i in range(elements.count() - 1, -1, -1):
                            el = elements.nth(i)
                            if el.is_visible():
                                el.click(force=True)
                                return True
                    except: pass
                return False

            print(\"      -> Clicking 'Clear' defaults...\")
            if not click_popup_btn(\"Clear\"):
                click_popup_btn(\"Select None\")
            time.sleep(1)

            print(f\"      -> Typing '{filter_value}'...\")
            page.keyboard.type(filter_value)
            time.sleep(1.5)

            print(f\"      -> Selecting '{filter_value}' box...\")
            if not click_popup_btn(filter_value):
                page.keyboard.press(\"ArrowDown\")
                time.sleep(0.5)
                page.keyboard.press(\"Space\")
            time.sleep(1)

            print(\"      -> Clicking 'OK' to lock filter...\")
            if not click_popup_btn(\"OK\"):
                if not click_popup_btn(\"Apply\"):
                    page.keyboard.press(\"Enter\")
            
            time.sleep(0.5)
            page.keyboard.press(\"Escape\") 
            print(\"      -> Waiting 12 seconds for dashboard data to reload...\")
            time.sleep(12) 

        try:
            for idx, item in enumerate(REPORTS_LIST):
                report_url = item['url']
                tab_name = item['tab']
                table_title = item['title']
                filename = item['filename']
                report_type = item.get('type', 'standard')

                file_path = os.path.join(TARGET_DIR, filename)
                print(f'\\n--- [{idx+1}/{len(REPORTS_LIST)}] Loading Tab: \"{tab_name}\" | Saving to: \"{filename}\" ---')

                page.goto(report_url, wait_until='domcontentloaded')
                time.sleep(15) 

                click_dashboard_tab(tab_name)
                apply_filter('SZM:', 'Gursewak Singh')

                if report_type == 'custom_filter':
                    if 'client_tag' in item: apply_filter('client_tags:', item['client_tag'])
                    if 'payment_mode' in item: apply_filter('payment_mode:', item['payment_mode'])
                    if 'client' in item: apply_filter('client:', item['client'])

                if 'sort_column' in item:
                    apply_sort(item['sort_column'])
                    
                time.sleep(5)

                # -----------------------------------------------
                # 2. STRICT SIZE-AWARE CROPPING ENGINE (FIXED)
                # -----------------------------------------------
                
                # Script logic to execute inside frames independently
                find_and_scroll_js = '''(title) => {
                    let els = Array.from(document.querySelectorAll('*'));
                    let matches = els.filter(el => el.textContent && el.textContent.trim() === title && el.offsetHeight > 0);
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
                    return false;
                }'''
                
                # STEP A: Safely search ALL iframes using Playwright instead of relying on DOM (fixes CORS)
                for f in [page] + page.frames:
                    try:
                        if f.evaluate(find_and_scroll_js, table_title): break
                    except: pass
                
                time.sleep(3) # Give browser time to settle scroll layout

                # Script logic to return coordinates from the frame
                find_and_crop_js = '''(title) => {
                    let els = Array.from(document.querySelectorAll('*'));
                    let matches = els.filter(el => el.textContent && el.textContent.trim() === title && el.offsetHeight > 0);
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
                    return null;
                }'''

                # STEP B: Find coordinates and calculate exact iframe spatial offsets
                crop_box = None
                for f in [page] + page.frames:
                    try:
                        raw_rect = f.evaluate(find_and_crop_js, table_title)
                        if raw_rect:
                            offset_x = 0
                            offset_y = 0
                            
                            # If it's an iframe, we need to add its coordinates to the cropped object
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
                print(f'Saved to Downloads: {filename} -> {status}')

        except Exception as e:
            print('An error occurred during execution...')
            traceback.print_exc()

        finally:
            context.close()

process_reports()
")
  
  py_run_string(py_script)
}

# --- 6. WHATSAPP SENDING FUNCTION ---
send_to_whatsapp <- function(file_path, title) {
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

# --- 7. EXECUTION & WHATSAPP DISTRIBUTION ---

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

# --- 8. HOURLY SCHEDULER ---
run_hourly_job <- function() {
  message("\n>>> HOURLY SCHEDULER STARTED <<<")
  message("Keep this console open to allow the script to run continuously.")
  
  repeat {
    job()
    message(sprintf("\n>>> Waiting for 1 hour until next run... (Press ESC or Ctrl+C to stop) <<<"))
    Sys.sleep(3600) 
  }
}

run_hourly_job()
