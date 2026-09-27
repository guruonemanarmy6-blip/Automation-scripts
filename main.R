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
  )
)

# --- 5. CORE CAPTURE FUNCTION ---

capture_all_reports <- function() {
  message(sprintf("Target directory resolved to: %s", downloads_folder))
  message("Opening background browser to process reports locally...")
  
  z_email <- "gursewak.singh@shadowfax.in"
  z_pass <- "Guru#24$2024"
  
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
Z_EMAIL = r'''", z_email, "'''
Z_PASS = r'''", z_pass, "'''

captured_results = []

def process_reports():
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=['--disable-blink-features=AutomationControlled']
        )
        
        context_args = {
            'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            'viewport': {'width': 1920, 'height': 1080},
            'timezone_id': 'Asia/Kolkata',
            'locale': 'en-IN'
        }
        
        context = browser.new_context(**context_args)
        context.add_init_script(\"Object.defineProperty(navigator, 'webdriver', {get: () => undefined})\")
        
        page = context.new_page()
        page.set_default_timeout(60000) 
        page.on('dialog', lambda dialog: dialog.accept())
        
        is_authenticated = False

        try:
            for idx, item in enumerate(REPORTS_LIST):
                try:
                    report_url = item['url']
                    tab_name = item['tab']
                    filename = item['filename']

                    file_path = os.path.join(TARGET_DIR, filename)
                    
                    print(f'\\n======================================================', flush=True)
                    print(f'--- [{idx+1}/{len(REPORTS_LIST)}] Loading Tab: \"{tab_name}\" | Saving to: \"{filename}\" ---', flush=True)

                    page.goto(report_url, wait_until='domcontentloaded')
                    
                    # -----------------------------------------------
                    # STATE-AWARE SAML LOGIN
                    # -----------------------------------------------
                    if not is_authenticated:
                        page.wait_for_timeout(5000)
                        if \"accounts.zoho\" in page.url or \"google.com\" in page.url:
                            print(\"      -> Detected Login Screen. Initiating automated SAML login...\", flush=True)
                            try:
                                saml_btn = page.locator(\"text='SAML - Zoho - Google SSO'\")
                                if saml_btn.count() > 0:
                                    print(\"         -> Clicking 'SAML - Zoho - Google SSO' button...\", flush=True)
                                    saml_btn.first.click()
                                    page.wait_for_timeout(6000)
                                    
                                email_input = page.locator(\"input[type='email']\")
                                if email_input.count() > 0 and email_input.first.is_visible(timeout=5000):
                                    print(\"         -> Entering Google SSO Email...\", flush=True)
                                    email_input.first.fill(Z_EMAIL)
                                    page.keyboard.press(\"Enter\")
                                    page.wait_for_timeout(4000)
                                
                                pass_input = page.locator(\"input[type='password']\")
                                if pass_input.count() > 0 and pass_input.first.is_visible(timeout=5000):
                                    print(\"         -> Entering Google SSO Password...\", flush=True)
                                    pass_input.first.fill(Z_PASS)
                                    page.keyboard.press(\"Enter\")
                                    page.wait_for_timeout(8000)
                                    
                                # --- LEVEL 36: THE VISUAL DIAGNOSTIC OVERRIDE ---
                                debug_login_path = os.path.join(TARGET_DIR, '0_DEBUG_LOGIN_STATE.png')
                                page.screenshot(path=debug_login_path, full_page=True)
                                captured_results.append({
                                    'index': 0, 'tab': 'DEBUG', 'title': 'CLOUD LOGIN SECURITY CHECK', 'file': '0_DEBUG_LOGIN_STATE.png', 'path': debug_login_path, 'status': 'DEBUG SENT'
                                })
                                print(\"         -> [!] DEBUG: Took a photograph of the post-password screen and dispatched to WhatsApp.\", flush=True)
                                
                                for _ in range(15):
                                    if \"analytics.zoho\" in page.url:
                                        print(\"         -> Successfully authenticated via Google SAML.\", flush=True)
                                        is_authenticated = True
                                        break
                                    page.wait_for_timeout(2000)
                                    
                            except Exception as e:
                                print(f\"         [!] SAML Automation Error: {e}\", flush=True)
                        
                        print(\"      -> Waiting 18 seconds for Zoho Dashboard to fully mount...\", flush=True)
                        page.wait_for_timeout(18000) 
                        
                        print(f\"      -> Forcing Re-Navigation to restore the Deep Link to: {tab_name}...\", flush=True)
                        page.goto(report_url, wait_until='domcontentloaded')
                        page.wait_for_timeout(10000)
                        
                    else:
                        page.wait_for_timeout(8000)
                    
                    # -----------------------------------------------
                    # DATA MANIPULATION (Skipped for Debug Truncation)
                    # -----------------------------------------------
                    print(\"      -> Script deliberately halted to await WhatsApp diagnostic review.\", flush=True)
                    break

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
