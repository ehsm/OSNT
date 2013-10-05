import os
from monitor import *
import wx
import  wx.lib.scrolledpanel as scrolled

class MainWindow(wx.Frame):
    def __init__(self):
        wx.Frame.__init__(self, None, wx.ID_ANY, "OSNT Monitor", size=(-1,-1))
        self.osnt_monitor_filter = OSNTMonitorFilter()
        self.osnt_monitor_stats = OSNTMonitorStats()
        self.osnt_monitor_cutter = OSNTMonitorCutter()
        self.osnt_monitor_timer = OSNTMonitorTimer()
        self.gui_init()



    def gui_init(self):

        self.SetMinSize(wx.Size(900,-1))
        # Stats display panel
        stats_title = wx.StaticText(self, label="STATS", style=wx.ALIGN_CENTER)
        stats_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        stats_title.SetBackgroundColour('GRAY')
        stats_panel = wx.Panel(self)
        stats_panel.SetBackgroundColour('WHEAT')
        stats_sizer = wx.GridSizer(5, 7, 10, 10)
        stats_panel.SetSizer(stats_sizer)
        self.pkt_cnt_txt = [None]*4
        self.byte_cnt_txt = [None]*4
        self.vlan_cnt_txt = [None]*4
        self.ip_cnt_txt = [None]*4
        self.udp_cnt_txt = [None]*4
        self.tcp_cnt_txt = [None]*4
        stats_sizer.AddMany([(wx.StaticText(stats_panel, label="Port", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Pkt Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Byte Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Vlan Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="IP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="UDP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="TCP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(4):
            self.pkt_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.byte_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.vlan_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.ip_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.udp_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.tcp_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            stats_sizer.AddMany([(wx.StaticText(stats_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.pkt_cnt_txt[i], 0, wx.EXPAND),
                (self.byte_cnt_txt[i], 0, wx.EXPAND),
                (self.vlan_cnt_txt[i], 0, wx.EXPAND),
                (self.ip_cnt_txt[i], 0, wx.EXPAND),
                (self.udp_cnt_txt[i], 0, wx.EXPAND),
                (self.tcp_cnt_txt[i], 0, wx.EXPAND)])

        # Filter rules display panel
        filter_title = wx.StaticText(self, label="FILTER RULES", style=wx.ALIGN_CENTER)
        filter_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        filter_title.SetBackgroundColour('GRAY')
        filter_legend = wx.Panel(self)
        filter_legend_sizer = wx.GridSizer(1, 9, 10, 5)
        filter_legend.SetSizer(filter_legend_sizer)
        filter_legend.SetBackgroundColour('WHEAT')
        filter_panel = scrolled.ScrolledPanel(self)
        filter_panel.SetupScrolling(scroll_x=False, scroll_y=True)
        filter_panel.SetBackgroundColour('WHEAT')
        filter_sizer = wx.GridSizer(OSNT_MON_FILTER_NUM_ENTRIES, 9, 10, 5)
        filter_panel.SetSizer(filter_sizer)
        self.src_ip_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.src_ip_mask_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.dst_ip_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.dst_ip_mask_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.l4ports_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.l4ports_mask_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.proto_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        self.proto_mask_txt = [None]*OSNT_MON_FILTER_NUM_ENTRIES
        filter_legend_sizer.AddMany([(wx.StaticText(filter_legend, label="Entry", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="SRC IP", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="SRC IP MASK", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="DST IP", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="DST IP MASK", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="L4 PORT", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="L4 PORT MASK", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="PROTO", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(filter_legend, label="PROTO MASK", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(OSNT_MON_FILTER_NUM_ENTRIES):
            self.src_ip_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.src_ip_mask_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.dst_ip_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.dst_ip_mask_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.l4ports_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.l4ports_mask_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.proto_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.proto_mask_txt[i] = wx.StaticText(filter_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            filter_sizer.AddMany([(wx.StaticText(filter_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.src_ip_txt[i], 0, wx.EXPAND),
                (self.src_ip_mask_txt[i], 0, wx.EXPAND),
                (self.dst_ip_txt[i], 0, wx.EXPAND),
                (self.dst_ip_mask_txt[i], 0, wx.EXPAND),
                (self.l4ports_txt[i], 0, wx.EXPAND),
                (self.l4ports_mask_txt[i], 0, wx.EXPAND),
                (self.proto_txt[i], 0, wx.EXPAND),
                (self.proto_mask_txt[i], 0, wx.EXPAND)])

        # Cutter and Timer
        cutter_timer_title = wx.StaticText(self, label="CUTTER and TIMER", style=wx.ALIGN_CENTER)
        cutter_timer_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        cutter_timer_title.SetBackgroundColour('GRAY')
        cutter_timer_panel = wx.Panel(self)
        cutter_timer_panel.SetBackgroundColour('WHEAT')
        cutter_timer_sizer = wx.BoxSizer(wx.HORIZONTAL)
        cutter_timer_panel.SetSizer(cutter_timer_sizer)
        self.cut_to_length = wx.StaticText(cutter_timer_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
        self.current_time = wx.StaticText(cutter_timer_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)

        cutter_timer_sizer.Add(wx.StaticText(cutter_timer_panel, wx.ID_ANY, label="Cut to Length:", style=wx.ALIGN_CENTER),
            1, wx.EXPAND)
        cutter_timer_sizer.Add(self.cut_to_length, 1, wx.EXPAND)
        cutter_timer_sizer.Add(wx.StaticText(cutter_timer_panel, wx.ID_ANY, label="Current Time:", style=wx.ALIGN_CENTER),
            1, wx.EXPAND)
        cutter_timer_sizer.Add(self.current_time, 1, wx.EXPAND)

        # Logger
        logger_title = wx.StaticText(self, label="CONSOLE LOG", style=wx.ALIGN_CENTER)
        logger_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        logger_title.SetBackgroundColour('GRAY')
        self.logger = wx.TextCtrl(self, style=wx.TE_MULTILINE|wx.TE_READONLY)

        # Setting up the menu.
        console_menu = wx.Menu()
        config_filter_menu = console_menu.Append(wx.ID_ANY, "Config Filter", "Open Filter Configuration File")
        clear_filter_menu = console_menu.Append(wx.ID_ANY, "Clear Filter Rules", "Clear Filter Rules")
        enable_cutter_menu = console_menu.Append(wx.ID_ANY, "Enable Cutter", "Enable Cutter")
        disable_cutter_menu = console_menu.Append(wx.ID_ANY, "Disable Cutter", "Disable Cutter")
        reset_stats_menu = console_menu.Append(wx.ID_ANY, "Reset Stats", "Reset Stats")
        reset_timer_menu = console_menu.Append(wx.ID_ANY, "Reset Timer", "Reset Timer")
   
        # Creating the menubar.
        menuBar = wx.MenuBar()
        menuBar.Append(console_menu, "&Console")
        self.SetMenuBar(menuBar)  # Adding the MenuBar to the Frame content.
   
        # Use some sizers to see layout options
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.sizer.Add(stats_title, 1, wx.EXPAND)
        self.sizer.Add(stats_panel, 6, wx.EXPAND)
        self.sizer.Add(filter_title, 1, wx.EXPAND)
        self.sizer.Add(filter_legend, 1, wx.EXPAND)
        self.sizer.Add(filter_panel, 10, wx.EXPAND)
        self.sizer.Add(cutter_timer_title, 1, wx.EXPAND)
        self.sizer.Add(cutter_timer_panel, 1.5, wx.EXPAND)
        self.sizer.Add(logger_title, 1, wx.EXPAND)
        self.sizer.Add(self.logger, 6, wx.EXPAND)
   
        #Layout sizers
        self.SetSizer(self.sizer)
        self.SetAutoLayout(1)
        self.sizer.Fit(self)
        self.Show()

    def display_filter_rules(self):
        for i in range(OSNT_MON_FILTER_NUM_ENTRIES):
            self.src_ip_txt[i].SetLabel(self.osnt_monitor_filter.src_ip_table[i])
        return

    def OnConfigFilter(self, event):
        return

    def OnClearFilter(self, event):
        return

    def OnEnableCutter(self, event):
        return

    def OnDisableCutter(self, event):
        return

    def OnResetStats(self, event):
        return

    def OnResetTimer(self, event):
        return
   
app = wx.App(False)
frame = MainWindow()
app.MainLoop()

