################################################################################
#
#  NetFPGA-10G http://www.netfpga.org
#
#  Author:
#        Yilong Geng
#
#  Description:
#        Code for the OSNT Monitor GUI
#
#  Copyright notice:
#        Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
#                                 Junior University
#
#  Licence:
#        This file is part of the NetFPGA 10G development base package.
#
#        This file is free code: you can redistribute it and/or modify it under
#        the terms of the GNU Lesser General Public License version 2.1 as
#        published by the Free Software Foundation.
#
#        This package is distributed in the hope that it will be useful, but
#        WITHOUT ANY WARRANTY; without even the implied warranty of
#        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#        Lesser General Public License for more details.
#
#        You should have received a copy of the GNU Lesser General Public
#        License along with the NetFPGA source package.  If not, see
#        http://www.gnu.org/licenses/.
#
#


import os
from monitor import *
import wx
import  wx.lib.scrolledpanel as scrolled
from axi import *

class MainWindow(wx.Frame):
    def __init__(self):
        wx.Frame.__init__(self, None, wx.ID_ANY, "OSNT Monitor", size=(-1,-1))
        self.gui_init()
        self.osnt_monitor_filter = OSNTMonitorFilter()
        self.osnt_monitor_stats = OSNTMonitorStats()
        self.osnt_monitor_cutter = OSNTMonitorCutter()
        self.osnt_monitor_timer = OSNTMonitorTimer()

        # Initialize filter display
        self.display_filter_rules()

        # Periodically refresh stats
        self.stats_timer = wx.Timer(self)
        self.Bind(wx.EVT_TIMER, self.refresh_stats, self.stats_timer)
        self.stats_timer.Start(1000)

        # Initialize cutter display
        self.osnt_monitor_cutter.disable_cut()
        self.display_cutter_status()


    def gui_init(self):

        self.SetMinSize(wx.Size(900,-1))
        # Stats display panel
        stats_title = wx.StaticText(self, label="STATS", style=wx.ALIGN_CENTER)
        stats_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        stats_title.SetBackgroundColour('GRAY')
        stats_panel = wx.Panel(self)
        stats_panel.SetBackgroundColour('WHEAT')
        stats_sizer = wx.GridSizer(5, 8, 10, 10)
        stats_panel.SetSizer(stats_sizer)
        self.pkt_cnt_txt = [None]*4
        self.byte_cnt_txt = [None]*4
        self.vlan_cnt_txt = [None]*4
        self.ip_cnt_txt = [None]*4
        self.udp_cnt_txt = [None]*4
        self.tcp_cnt_txt = [None]*4
        self.pktps_txt = [None]*4
        self.byteps_txt = [None]*4
        stats_sizer.AddMany([(wx.StaticText(stats_panel, label="Port", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Pkt Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            #(wx.StaticText(stats_panel, label="Byte Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Vlan Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="IP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="UDP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="TCP Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Pkts/s", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Bits/s", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(4):
            self.pkt_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.byte_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.byte_cnt_txt[i].Hide()
            self.vlan_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.ip_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.udp_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.tcp_cnt_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.pktps_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            self.byteps_txt[i] = wx.StaticText(stats_panel, wx.ID_ANY, label="", style=wx.ALIGN_CENTER)
            stats_sizer.AddMany([(wx.StaticText(stats_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.pkt_cnt_txt[i], 0, wx.EXPAND),
                #(self.byte_cnt_txt[i], 0, wx.EXPAND),
                (self.vlan_cnt_txt[i], 0, wx.EXPAND),
                (self.ip_cnt_txt[i], 0, wx.EXPAND),
                (self.udp_cnt_txt[i], 0, wx.EXPAND),
                (self.tcp_cnt_txt[i], 0, wx.EXPAND),
                (self.pktps_txt[i], 0, wx.EXPAND),
                (self.byteps_txt[i], 0, wx.EXPAND)])

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

        self.Bind(wx.EVT_MENU, self.OnConfigFilter, config_filter_menu)
        self.Bind(wx.EVT_MENU, self.OnClearFilter, clear_filter_menu)
        self.Bind(wx.EVT_MENU, self.OnEnableCutter, enable_cutter_menu)
        self.Bind(wx.EVT_MENU, self.OnDisableCutter, disable_cutter_menu)
        self.Bind(wx.EVT_MENU, self.OnResetStats, reset_stats_menu)
        self.Bind(wx.EVT_MENU, self.OnResetTimer, reset_timer_menu)
   
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
            if (int(self.osnt_monitor_filter.src_ip_table[i], 16) != 0 or
                    int(self.osnt_monitor_filter.src_ip_mask_table[i], 16) != int("0xffffffff", 16) or
                    int(self.osnt_monitor_filter.dst_ip_table[i], 16) != 0 or
                    int(self.osnt_monitor_filter.dst_ip_mask_table[i], 16) != int("0xffffffff", 16) or
                    int(self.osnt_monitor_filter.l4ports_table[i], 16) != 0 or
                    int(self.osnt_monitor_filter.l4ports_mask_table[i], 16) != int("0xffffffff", 16) or
                    int(self.osnt_monitor_filter.proto_table[i], 16) != 0 or
                    int(self.osnt_monitor_filter.proto_mask_table[i], 16) != int("0xff", 16)):

                self.src_ip_txt[i].SetLabel(hex2ip(self.osnt_monitor_filter.src_ip_table[i]))
                self.src_ip_mask_txt[i].SetLabel(hex2ip(self.osnt_monitor_filter.src_ip_mask_table[i]))
                self.dst_ip_txt[i].SetLabel(hex2ip(self.osnt_monitor_filter.dst_ip_table[i]))
                self.dst_ip_mask_txt[i].SetLabel(hex2ip(self.osnt_monitor_filter.dst_ip_mask_table[i]))
                self.l4ports_txt[i].SetLabel(self.osnt_monitor_filter.l4ports_table[i])
                self.l4ports_mask_txt[i].SetLabel(self.osnt_monitor_filter.l4ports_mask_table[i])
                self.proto_txt[i].SetLabel(self.osnt_monitor_filter.proto_table[i])
                self.proto_mask_txt[i].SetLabel(self.osnt_monitor_filter.proto_mask_table[i])
            else:
                self.src_ip_txt[i].SetLabel("N/A")
                self.src_ip_mask_txt[i].SetLabel("N/A")
                self.dst_ip_txt[i].SetLabel("N/A")
                self.dst_ip_mask_txt[i].SetLabel("N/A")
                self.l4ports_txt[i].SetLabel("N/A")
                self.l4ports_mask_txt[i].SetLabel("N/A")
                self.proto_txt[i].SetLabel("N/A")
                self.proto_mask_txt[i].SetLabel("N/A")
        return

    def refresh_stats(self, event):
        self.osnt_monitor_stats.get_stats()

        time_high = int(self.osnt_monitor_stats.time_high, 16)
        time_low = int(self.osnt_monitor_stats.time_low, 16)
        time_low = ((time_low * 1000000000) >> 32)/float(1000000000)
        time_new = time_high + time_low
        time_old = self.current_time.GetLabel()
        if len(time_old) == 0:
            time_old = 0
        time_old = float(time_old)
        time_elapsed = time_new - time_old
        self.current_time.SetLabel(str(time_new))

        for i in range(4):
            pkt_cnt_old = self.pkt_cnt_txt[i].GetLabel()
            if len(pkt_cnt_old) == 0:
                pkt_cnt_old = 0
            pkt_cnt_old = float(pkt_cnt_old)
            pkt_cnt_new = int(self.osnt_monitor_stats.pkt_cnt[i], 16)
            if pkt_cnt_new >= pkt_cnt_old:
                pkt_cnt = pkt_cnt_new - pkt_cnt_old;
            else:
                pkt_cnt = pkt_cnt_new + ((1<<32) - pkt_cnt_old);

            self.pktps_txt[i].SetLabel(translateRate(pkt_cnt/time_elapsed))
            byte_cnt_old = self.byte_cnt_txt[i].GetLabel()
            if len(byte_cnt_old) == 0:
                byte_cnt_old = 0
            byte_cnt_old = float(byte_cnt_old)
            byte_cnt_new = int(self.osnt_monitor_stats.byte_cnt[i], 16)
            if byte_cnt_new >= byte_cnt_old:
                byte_cnt = byte_cnt_new - byte_cnt_old;
            else:
                byte_cnt = byte_cnt_new + ((1<<32) - byte_cnt_old);

            self.byteps_txt[i].SetLabel(translateRate((8*byte_cnt+32*pkt_cnt)/time_elapsed))

            self.pkt_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.pkt_cnt[i], 16)))
            self.byte_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.byte_cnt[i], 16)))
            self.vlan_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.vlan_cnt[i], 16)))
            self.ip_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.ip_cnt[i], 16)))
            self.udp_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.udp_cnt[i], 16)))
            self.tcp_cnt_txt[i].SetLabel(str(int(self.osnt_monitor_stats.tcp_cnt[i], 16)))


    def display_cutter_status(self):
        self.osnt_monitor_cutter.get_status()
        if int(self.osnt_monitor_cutter.enable, 16) == 1:
            self.cut_to_length.SetLabel(str(int(self.osnt_monitor_cutter.bytes, 16)))
        else:
            self.cut_to_length.SetLabel("N/A")

    def OnConfigFilter(self, event):
        dlg = wx.FileDialog(self, "Choose a file", "", "", "*.*", wx.OPEN)
        if dlg.ShowModal() == wx.ID_OK:
            self.osnt_monitor_filter.clear_rules()
            with open(os.path.join(dlg.GetDirectory(), dlg.GetFilename()), 'r') as f:
                for line in f:
                    line = line.lstrip()
                    if len(line) > 0 and line[0] != '#':
                        rule = line.split()
                        entry = int(rule[0])
                        self.osnt_monitor_filter.src_ip_table[entry] = ip2hex(rule[1])
                        self.osnt_monitor_filter.src_ip_mask_table[entry] = ip2hex(rule[2])
                        self.osnt_monitor_filter.dst_ip_table[entry] = ip2hex(rule[3])
                        self.osnt_monitor_filter.dst_ip_mask_table[entry] = ip2hex(rule[4])
                        self.osnt_monitor_filter.l4ports_table[entry] = rule[5]
                        self.osnt_monitor_filter.l4ports_mask_table[entry] = rule[6]
                        self.osnt_monitor_filter.proto_table[entry] = rule[7]
                        self.osnt_monitor_filter.proto_mask_table[entry] = rule[8]
        dlg.Destroy()
        self.osnt_monitor_filter.synch_rules()
        self.display_filter_rules()

        self.logger.AppendText("Filter Configuration Completed.\n")
        return

    def OnClearFilter(self, event):
        self.osnt_monitor_filter.clear_rules()
        self.display_filter_rules()
        self.logger.AppendText("Filter Rules Cleared.\n")
        return

    def OnEnableCutter(self, event):
        dlg = wx.TextEntryDialog(self, "Cut to Length:", "Enable Cutter", "64")
        if dlg.ShowModal() == wx.ID_OK:
            length = int(dlg.GetValue())
            if length > BYTE_DATA_WIDTH:
                self.osnt_monitor_cutter.enable_cut(length)
                self.logger.AppendText("Cutter set to length %d bytes.\n" % length)
            else:
                self.logger.AppendText("Cutter length has to be greater than 32.\n")
        dlg.Destroy()
        self.display_cutter_status()
        return

    def OnDisableCutter(self, event):
        self.osnt_monitor_cutter.disable_cut()
        self.display_cutter_status()
        self.logger.AppendText("Cutter disabled.\n")
        return

    def OnResetStats(self, event):
        self.osnt_monitor_stats.reset()
        self.logger.AppendText("Completed reseting stats.\n")
        return

    def OnResetTimer(self, event):
        self.osnt_monitor_timer.reset_time()
        self.logger.AppendText("Completed reseting timer.\n")
        return

def translateRate(rate):

    if rate >= 1000000000:
        return str(round(rate/1000000000.0, 3)) + 'G';
    elif rate >= 1000000:
        return str(round(rate/1000000.0, 3)) + 'M';
    elif rate >= 1000:
        return str(round(rate/1000.0, 3)) + 'K';
    else:
        return str(round(rate, 3));

app = wx.App(False)
frame = MainWindow()
app.MainLoop()

