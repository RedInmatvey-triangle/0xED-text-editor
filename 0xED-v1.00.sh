import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk
import tkinter.font as tkFont
import requests
import re

DEESEEK_API_KEY = "sk-849ea946f49b46919374708d99becd87"
DEESEEK_API_URL = "https://api.deepseek.com/v1/chat/completions"

PYTHON_KEYWORDS = [
    'False', 'class', 'finally', 'is', 'return', 'None', 'continue', 'for',
    'lambda', 'try', 'True', 'def', 'from', 'nonlocal', 'while', 'and',
    'del', 'global', 'not', 'with', 'as', 'elif', 'if', 'or', 'yield',
    'assert', 'else', 'import', 'pass', 'break', 'except', 'in', 'raise'
]

class TextLineNumbers(tk.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.textwidget = None
        self.marked_lines = set()

    def attach(self, text_widget):
        self.textwidget = text_widget

    def mark_line(self, lineno):
        self.marked_lines.add(lineno)
        self.redraw()

    def unmark_line(self, lineno):
        if lineno in self.marked_lines:
            self.marked_lines.remove(lineno)
            self.redraw()

    def redraw(self, *args):
        self.delete("all")
        i = self.textwidget.index("@0,0")
        while True:
            dline = self.textwidget.dlineinfo(i)
            if dline is None:
                break
            y = dline[1]
            linenum = int(str(i).split(".")[0])
            self.create_text(2, y, anchor="nw", text=str(linenum), fill="black")
            if linenum in self.marked_lines:
                r = 5
                self.create_oval(
                    25 - r, y + 4 - r, 25 + r, y + 4 + r,
                    fill="red", outline=""
                )
            i = self.textwidget.index(f"{i}+1line")

class TextEditorTab(tk.Frame):
    def __init__(self, parent, bg_color, button_fg):
        super().__init__(parent)
        self.bg_color = bg_color
        self.button_fg = button_fg
        self.filename = None
        self.edit_modified_flag = False
        self._create_widgets()
        self._setup_syntax_highlighting()
        self._highlight_syntax()

    def _create_widgets(self):
        container = tk.Frame(self)
        container.pack(fill=tk.BOTH, expand=True)

        self.vscrollbar = tk.Scrollbar(container, orient=tk.VERTICAL)
        self.vscrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self.hscrollbar = tk.Scrollbar(container, orient=tk.HORIZONTAL)
        self.hscrollbar.pack(side=tk.BOTTOM, fill=tk.X)

        self.linenumbers = TextLineNumbers(container, width=40, bg="#d3d3d3", highlightthickness=0)
        self.linenumbers.pack(side=tk.LEFT, fill=tk.Y)

        self.textarea = tk.Text(
            container,
            undo=True,
            bg=self.bg_color,
            fg=self.button_fg,
            insertbackground="black",
            borderwidth=0,
            padx=4,
            pady=4,
            wrap=tk.NONE,
            yscrollcommand=self.vscrollbar.set,
            xscrollcommand=self.hscrollbar.set,
        )
        self.textarea.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True)

        self.vscrollbar.config(command=self.textarea.yview)
        self.hscrollbar.config(command=self.textarea.xview)

        self.linenumbers.attach(self.textarea)

        self.textarea.bind("<<Change>>", self._on_change)
        self.textarea.bind("<Configure>", self._on_change)
        self.textarea.bind("<KeyRelease>", self._on_change)
        self.textarea.bind("<MouseWheel>", self._on_change)
        self.textarea.bind("<Button-4>", self._on_change)
        self.textarea.bind("<Button-5>", self._on_change)
        self.textarea.bind("<<Modified>>", self._on_modified)
        self.textarea.bind("<Double-Button-1>", self.on_double_click_line)

        self.textarea.bind("<KeyRelease>", self._highlight_syntax)  # подсветка при наборе текста

        # Контекстное меню с операциями с текстом
        self.context_menu = tk.Menu(self.textarea, tearoff=0)
        self.context_menu.add_command(label="Отменить", command=lambda: self.textarea.event_generate("<<Undo>>"))
        self.context_menu.add_command(label="Вернуть", command=lambda: self.textarea.event_generate("<<Redo>>"))
        self.context_menu.add_separator()
        self.context_menu.add_command(label="Вырезать", command=self.cut_text)
        self.context_menu.add_command(label="Копировать", command=self.copy_text)
        self.context_menu.add_command(label="Вставить", command=self.paste_text)
        self.context_menu.add_command(label="Удалить", command=self.delete_selection)
        self.textarea.bind("<Button-3>", self.show_context_menu)

        self.textarea._orig_insert = self.textarea.insert
        def new_insert(index, text, *args):
            self.textarea._orig_insert(index, text, *args)
            self.textarea.event_generate("<<Change>>")
            self._highlight_syntax()
        self.textarea.insert = new_insert

        self.textarea._orig_delete = self.textarea.delete
        def new_delete(index1, index2=None):
            self.textarea._orig_delete(index1, index2)
            self.textarea.event_generate("<<Change>>")
            self._highlight_syntax()
        self.textarea.delete = new_delete

    def _setup_syntax_highlighting(self):
        self.textarea.tag_configure("keyword", foreground="#ff4500")
        self.textarea.tag_configure("comment", foreground="#008000", font=("Arial", 10, "italic"))
        self.textarea.tag_configure("string", foreground="#b22222")

    def _highlight_syntax(self, event=None):
        self.textarea.tag_remove("keyword", "1.0", tk.END)
        self.textarea.tag_remove("comment", "1.0", tk.END)
        self.textarea.tag_remove("string", "1.0", tk.END)

        content = self.textarea.get("1.0", tk.END)

        # Подсветка ключевых слов
        for keyword in PYTHON_KEYWORDS:
            start = "1.0"
            while True:
                pos = self.textarea.search(r'\b' + keyword + r'\b', start, stopindex=tk.END, regexp=True)
                if not pos:
                    break
                end = f"{pos}+{len(keyword)}c"
                self.textarea.tag_add("keyword", pos, end)
                start = end

        # Подсветка комментариев (# и до конца строки)
        comment_pattern = re.compile(r"#.*")
        for match in comment_pattern.finditer(content):
            start_index = f"1.0+{match.start()}c"
            end_index = f"1.0+{match.end()}c"
            self.textarea.tag_add("comment", start_index, end_index)

        # Подсветка строк (одинарные и двойные кавычки)
        string_pattern = re.compile(r"(\".*?\"|\'.*?\')")
        for match in string_pattern.finditer(content):
            start_index = f"1.0+{match.start()}c"
            end_index = f"1.0+{match.end()}c"
            self.textarea.tag_add("string", start_index, end_index)

    def show_context_menu(self, event):
        try:
            self.context_menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.context_menu.grab_release()

    def delete_selection(self):
        try:
            self.textarea.delete("sel.first", "sel.last")
        except tk.TclError:
            pass

    def _on_change(self, event=None):
        self.linenumbers.redraw()

    def _on_modified(self, event=None):
        self.edit_modified_flag = self.textarea.edit_modified()
        self.textarea.edit_modified(False)

    def on_double_click_line(self, event):
        index = self.textarea.index(f"@{event.x},{event.y}")
        lineno = int(str(index).split(".")[0])
        if lineno in self.linenumbers.marked_lines:
            self.linenumbers.unmark_line(lineno)
        else:
            self.linenumbers.mark_line(lineno)

    def _confirm_unsaved(self):
        if self.edit_modified_flag:
            result = messagebox.askyesnocancel(
                "Сохранить изменения?", "Вы хотите сохранить изменения перед продолжением?"
            )
            if result is None:
                return False
            if result:
                return self.save_file()
        return True

    def new_file(self):
        if self._confirm_unsaved():
            self.textarea.delete(1.0, tk.END)
            self.filename = None
            self.edit_modified_flag = False
            self.linenumbers.marked_lines.clear()
            self.linenumbers.redraw()
            self._highlight_syntax()
            return True
        return False

    def open_file(self, filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                content = f.read()
            self.textarea.delete(1.0, tk.END)
            self.textarea.insert(tk.END, content)
            self.filename = filepath
            self.edit_modified_flag = False
            self.linenumbers.marked_lines.clear()
            self.linenumbers.redraw()
            self._highlight_syntax()
            return True
        except Exception as e:
            messagebox.showerror("Ошибка", f"Не удалось открыть файл\n{e}")
            return False

    def save_file(self):
        if self.filename:
            try:
                content = self.textarea.get(1.0, tk.END)
                with open(self.filename, "w", encoding="utf-8") as f:
                    f.write(content)
                self.edit_modified_flag = False
                messagebox.showinfo("Сохранено", "Файл успешно сохранён")
                return True
            except Exception as e:
                messagebox.showerror("Ошибка", f"Не удалось сохранить файл\n{e}")
                return False
        else:
            return self.save_as_file()

    def save_as_file(self):
        file = filedialog.asksaveasfilename(
            defaultextension=".txt", filetypes=[("Текстовые файлы", "*.txt"), ("Все файлы", "*.*")]
        )
        if file:
            try:
                content = self.textarea.get(1.0, tk.END)
                with open(file, "w", encoding="utf-8") as f:
                    f.write(content)
                self.filename = file
                self.edit_modified_flag = False
                messagebox.showinfo("Сохранено", "Файл успешно сохранён")
                return True
            except Exception as e:
                messagebox.showerror("Ошибка", f"Не удалось сохранить файл\n{e}")
                return False
        return False

    def cut_text(self):
        try:
            selected_text = self.textarea.get("sel.first", "sel.last")
            self.clipboard_clear()
            self.clipboard_append(selected_text)
            self.textarea.delete("sel.first", "sel.last")
        except tk.TclError:
            pass

    def copy_text(self):
        try:
            selected_text = self.textarea.get("sel.first", "sel.last")
            self.clipboard_clear()
            self.clipboard_append(selected_text)
        except tk.TclError:
            pass

    def paste_text(self):
        try:
            pasted_text = self.clipboard_get()
            self.textarea.insert("insert", pasted_text)
            self._highlight_syntax()
        except tk.TclError:
            pass

    def find_text(self):
        search_term = simpledialog.askstring("Поиск", "Введите текст для поиска:")
        self.textarea.tag_remove("found", "1.0", tk.END)
        if search_term:
            idx = "1.0"
            while True:
                idx = self.textarea.search(search_term, idx, nocase=1, stopindex=tk.END)
                if not idx:
                    break
                lastidx = f"{idx}+{len(search_term)}c"
                self.textarea.tag_add("found", idx, lastidx)
                idx = lastidx
            self.textarea.tag_config("found", foreground="red", background="yellow")

class TextEditor:
    def __init__(self, root):
        self.root = root
        self.root.title("0xED")
        self.root.geometry("800x600")

        # Текущая тема: "light" или "dark"
        self.current_theme = "light"
        self.bg_color = "white"
        self.button_fg = "black"
        self.btn_font = tkFont.Font(family="Arial", size=10, weight="normal")

        self._create_topbar()

        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill=tk.BOTH, expand=True)
        self.tabs = []

        self.add_tab()

        self.notebook.bind("<<NotebookTabChanged>>", self.on_tab_change)

    def _make_button_style(self, btn):
        btn.config(
            bg="white",
            fg=self.button_fg,
            font=self.btn_font,
            relief=tk.FLAT,
            borderwidth=0,
            highlightthickness=0,
            padx=10,
            pady=5,
        )
        btn.bind("<Enter>", lambda e: btn.config(bg="#ff4444"))
        btn.bind("<Leave>", lambda e: btn.config(bg="white"))
        btn.bind("<ButtonPress>", lambda e: btn.config(bg="#ff0000"))
        btn.bind(
            "<ButtonRelease>",
            lambda e: btn.config(bg="#ff4444" if btn.winfo_containing(e.x_root, e.y_root) == btn else "white"),
        )

    def _create_topbar(self):
        self.topbar = tk.Frame(self.root, bg="white")
        self.topbar.pack(side=tk.TOP, fill=tk.X)

        self.file_btn = tk.Menubutton(self.topbar, text="Файл")
        self.file_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.file_btn)
        file_menu = tk.Menu(
            self.file_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        file_menu.add_command(label="Новый", command=self.new_file)
        file_menu.add_command(label="Открыть...", command=self.open_file)
        file_menu.add_command(label="Сохранить", command=self.save_file)
        file_menu.add_command(label="Сохранить как...", command=self.save_as_file)
        file_menu.add_separator()
        file_menu.add_command(label="Выход", command=self.root.quit)
        self.file_btn.config(menu=file_menu)

        self.edit_btn = tk.Menubutton(self.topbar, text="Правка")
        self.edit_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.edit_btn)
        edit_menu = tk.Menu(
            self.edit_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        edit_menu.add_command(label="Вырезать", command=self.cut_text)
        edit_menu.add_command(label="Копировать", command=self.copy_text)
        edit_menu.add_command(label="Вставить", command=self.paste_text)
        self.edit_btn.config(menu=edit_menu)

        self.view_btn = tk.Menubutton(self.topbar, text="Вид")
        self.view_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.view_btn)
        view_menu = tk.Menu(
            self.view_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        # Переключатель темы - использовать add_radiobutton
        view_menu.add_radiobutton(label="Светлая тема", variable=tk.StringVar(value=self.current_theme),
                                  value="light", command=lambda: self.change_theme("light"))
        view_menu.add_radiobutton(label="Темная тема", variable=tk.StringVar(value=self.current_theme),
                                  value="dark", command=lambda: self.change_theme("dark"))
        self.view_btn.config(menu=view_menu)

        self.tabs_btn = tk.Menubutton(self.topbar, text="Вкладки")
        self.tabs_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.tabs_btn)
        self.tabs_menu = tk.Menu(
            self.tabs_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        self.tabs_menu.add_command(label="Создать вкладку", command=self.add_tab)
        self.tabs_menu.add_command(label="Удалить текущую вкладку", command=self.delete_current_tab)
        self.tabs_btn.config(menu=self.tabs_menu)

        self.ai_btn = tk.Menubutton(self.topbar, text="ИИ")
        self.ai_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.ai_btn)
        ai_menu = tk.Menu(
            self.ai_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        ai_menu.add_command(label="Чат с ИИ", command=self.open_ai_chat)
        self.ai_btn.config(menu=ai_menu)

        self.run_btn = tk.Menubutton(self.topbar, text="Запустить")
        self.run_btn.pack(side=tk.LEFT, padx=2, pady=2)
        self._make_button_style(self.run_btn)
        run_menu = tk.Menu(
            self.run_btn,
            tearoff=0,
            bg="white",
            fg=self.button_fg,
            activebackground="#ff4444",
            activeforeground="white",
        )
        run_menu.add_command(label="Запустить", command=self.run_python_code)
        run_menu.add_command(label="Дебаггинг", command=self.debug_python_code)
        self.run_btn.config(menu=run_menu)

        self.help_btn = tk.Button(self.topbar, text="Справка", command=self.show_about)
        self.help_btn.pack(side=tk.LEFT, padx=2, pady=5)
        self._make_button_style(self.help_btn)

        self.find_btn = tk.Button(self.topbar, text="Поиск", command=self.find_text)
        self.find_btn.pack(side=tk.LEFT, padx=2, pady=5)
        self._make_button_style(self.find_btn)

    def change_theme(self, theme):
        if theme == self.current_theme:
            return
        self.current_theme = theme
        if theme == "light":
            self.bg_color = "white"
            self.button_fg = "black"
        else:
            self.bg_color = "#1e1e1e"
            self.button_fg = "#d4d4d4"
        # Обновляем все вкладки
        for tab in self.tabs:
            tab.textarea.config(bg=self.bg_color, fg=self.button_fg, insertbackground=self.button_fg)
            tab.linenumbers.config(bg="#d3d3d3" if theme == "light" else "#2e2e2e")
            tab._highlight_syntax()

        # Можно обновить цвета верхней панели и кнопок, если нужно
        self.topbar.config(bg=self.bg_color)
        for child in self.topbar.winfo_children():
            if isinstance(child, (tk.Button, tk.Menubutton)):
                fg_col = self.button_fg
                bg_col = self.bg_color
                child.config(fg=fg_col, bg=bg_col)

    def show_about(self):
        about_text = (
            "0xED — это простой текстовый редактор с подсветкой Python-синтаксиса, "
            "работой с вкладками, подсветкой ключевых слов, строк и комментариев.\n\n"
            "Реализован на Python с использованием Tkinter.\n\n"
            "Функции:\n"
            "- Работа с несколькими вкладками\n"
            "- Запуск и дебаггинг Python-кода\n"
            "- Подсветка синтаксиса Python\n"
            "- Поиск по тексту\n"
            "- Интеграция с Deepseek API для AI-чата\n"
            "- Светлая и темная темы интерфейса"
        )
        messagebox.showinfo("О программе 0xED", about_text)

    def open_ai_chat(self):
        chat_win = tk.Toplevel(self.root)
        chat_win.title("Чат с ИИ")
        chat_win.geometry("400x500")
        chat_win.config(bg="white")

        messages_text = tk.Text(chat_win, state=tk.DISABLED, wrap=tk.WORD, bg="white", fg="black",
                                font=self.btn_font)
        messages_text.pack(expand=True, fill=tk.BOTH, padx=5, pady=5)

        input_frame = tk.Frame(chat_win, bg="white")
        input_frame.pack(fill=tk.X, padx=5, pady=5)

        input_entry = tk.Entry(input_frame, font=self.btn_font)
        input_entry.pack(side=tk.LEFT, expand=True, fill=tk.X, padx=5)

        def send_message():
            user_msg = input_entry.get().strip()
            if user_msg:
                messages_text.config(state=tk.NORMAL)
                messages_text.insert(tk.END, f"Вы: {user_msg}\n")
                input_entry.delete(0, tk.END)
                try:
                    headers = {
                        "Authorization": f"Bearer {DEESEEK_API_KEY}",
                        "Content-Type": "application/json"
                    }
                    data = {
                        "model": "deepseek-chat",
                        "messages": [
                            {"role": "user", "content": user_msg}
                        ],
                        "temperature": 0.7
                    }
                    response = requests.post(DEESEEK_API_URL, json=data, headers=headers, timeout=15)
                    response.raise_for_status()
                    ai_response = response.json().get("choices", [{}])[0].get("message", {}).get("content", "")
                    if not ai_response:
                        ai_response = "ИИ не вернул ответ."
                except Exception as e:
                    ai_response = f"Ошибка запроса к ИИ: {e}"

                messages_text.insert(tk.END, f"ИИ: {ai_response}\n\n")
                messages_text.config(state=tk.DISABLED)
                messages_text.see(tk.END)

        send_button = tk.Button(input_frame, text="Отправить", command=send_message)
        send_button.pack(side=tk.RIGHT, padx=5)

        input_entry.bind("<Return>", lambda event: send_message())

    def get_current_tab(self):
        if not self.tabs:
            return None
        try:
            current_tab_index = self.notebook.index(self.notebook.select())
        except tk.TclError:
            return None
        return self.tabs[current_tab_index]

    def add_tab(self):
        tab = TextEditorTab(self.notebook, self.bg_color, self.button_fg)
        self.tabs.append(tab)
        self.notebook.add(tab, text="Новый файл")
        self.notebook.select(len(self.tabs) - 1)
        self.update_title()

    def delete_current_tab(self):
        current = self.get_current_tab()
        if current is None:
            return
        idx = self.notebook.index(self.notebook.select())
        if len(self.tabs) <= 1:
            messagebox.showinfo("Информация", "Нельзя удалить последнюю вкладку.")
            return
        if current._confirm_unsaved():
            self.notebook.forget(idx)
            self.tabs.pop(idx)
            self.update_title()

    def new_file(self):
        current = self.get_current_tab()
        if current and current.new_file():
            self.update_title()
        elif current is None:
            self.add_tab()

    def open_file(self):
        current = self.get_current_tab()
        if current is None:
            self.add_tab()
            current = self.get_current_tab()
        if current and current._confirm_unsaved():
            file = filedialog.askopenfilename(
                defaultextension=".txt",
                filetypes=[("Текстовые файлы", "*.txt"), ("Все файлы", "*.*")],
            )
            if file:
                if current.open_file(file):
                    filename_only = file.split("/")[-1]
                    self.notebook.tab(self.notebook.select(), text=filename_only)
                    self.update_title()

    def save_file(self):
        current = self.get_current_tab()
        if current and current.save_file():
            self.update_title()

    def save_as_file(self):
        current = self.get_current_tab()
        if current and current.save_as_file():
            filename_only = current.filename.split("/")[-1]
            self.notebook.tab(self.notebook.select(), text=filename_only)
            self.update_title()

    def cut_text(self):
        current = self.get_current_tab()
        if current:
            current.cut_text()

    def copy_text(self):
        current = self.get_current_tab()
        if current:
            current.copy_text()

    def paste_text(self):
        current = self.get_current_tab()
        if current:
            current.paste_text()

    def find_text(self):
        current = self.get_current_tab()
        if current:
            current.find_text()

    def on_tab_change(self, event):
        self.update_title()

    def update_title(self):
        current = self.get_current_tab()
        if current:
            title = current.filename if current.filename else "Новый файл"
            self.root.title(f"0xED - {title}")
        else:
            self.root.title("0xED")

    def run_python_code(self):
        import subprocess
        import threading
        current = self.get_current_tab()
        if current:
            code = current.textarea.get("1.0", tk.END)
            output_win = tk.Toplevel(self.root)
            output_win.title("Результат выполнения")
            output_win.geometry("600x400")
            txt = tk.Text(output_win, bg="black", fg="white", wrap=tk.NONE)
            txt.pack(expand=True, fill=tk.BOTH)
            txt.insert(tk.END, "Выполнение кода...\n\n")
            txt.config(state=tk.DISABLED)

            def execute_code():
                try:
                    proc = subprocess.Popen(
                        ["python3", "-c", code],
                        stdout=subprocess.PIPE,
                        stderr=subprocess.PIPE,
                        text=True
                    )
                    stdout, stderr = proc.communicate()
                    result = ""
                    if stdout:
                        result += "Вывод:\n" + stdout + "\n"
                    if stderr:
                        result += "Ошибки:\n" + stderr + "\n"
                    if not stdout and not stderr:
                        result = "Нет вывода."
                except Exception as e:
                    result = f"Ошибка запуска кода: {e}"

                txt.config(state=tk.NORMAL)
                txt.delete("1.0", tk.END)
                txt.insert(tk.END, result)
                txt.config(state=tk.DISABLED)

            threading.Thread(target=execute_code).start()

    def debug_python_code(self):
        import ast
        current = self.get_current_tab()
        if current:
            code = current.textarea.get("1.0", tk.END)
            output_win = tk.Toplevel(self.root)
            output_win.title("Дебаггинг кода")
            output_win.geometry("600x400")
            txt = tk.Text(output_win, bg="black", fg="white", wrap=tk.NONE)
            txt.pack(expand=True, fill=tk.BOTH)

            try:
                ast.parse(code)
                msg = "Синтаксических ошибок не обнаружено."
            except SyntaxError as e:
                msg = f"Синтаксическая ошибка:\nСтрока {e.lineno}, Колонка {e.offset}\n{e.text}\n{e.msg}"
            except Exception as e:
                msg = f"Ошибка анализа кода: {e}"

            txt.insert(tk.END, msg)

if __name__ == "__main__":
    root = tk.Tk()
    app = TextEditor(root)
    root.mainloop()
