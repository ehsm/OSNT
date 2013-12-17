import os
from generator import *
import wx
import  wx.lib.scrolledpanel as scrolled
import wx.lib.intctrl
from axi import *
import datetime

class MainWindow(wx.Frame):
    def __init__(self):
        wx.Frame.__init__(self, None, wx.ID_ANY, "OSNT Generator", size=(-1,-1))

        self.average_pkt_len = {'nf0':1500, 'nf1':1500, 'nf2':1500, 'nf3':1500}
        self.average_word_cnt = {'nf0':47, 'nf1':47, 'nf2':47, 'nf3':47}
        self.pkts_loaded = {'nf0':0, 'nf1':0, 'nf2':0, 'nf3':0}
        self.pcaps = {}
        self.rate_limiters = [None]*4
        self.delays = [None]*4
        for i in range(4):
            iface = 'nf' + str(i)
            self.rate_limiters[i] = OSNTRateLimiter(iface)
            self.delays[i] = OSNTDelay(iface)

        self.pcap_engine = OSNTGeneratorPcapEngine()

        self.delay_header_extractor = OSNTDelayHeaderExtractor()
        self.delay_header_extractor.set_reset(False)
        self.delay_header_extractor.set_enable(False)

        self.gui_init()
        self.readings_init()

    def gui_init(self):

        self.SetMinSize(wx.Size(900,-1))

        # Pcap engine panel
        pcap_title = wx.StaticText(self, label="PCAP ENGINE", style=wx.ALIGN_CENTER)
        pcap_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        pcap_title.SetBackgroundColour('GRAY')
        pcap_panel = wx.Panel(self)
        pcap_panel.SetBackgroundColour('WHEAT')
        pcap_sizer = wx.GridSizer(5, 6, 10, 10)
        pcap_panel.SetSizer(pcap_sizer)
        self.pcap_file_btn = [None]*4
        self.replay_cnt_input = [None]*4
        self.replay_cnt_txt = [None]*4
        self.mem_addr_low_txt = [None]*4
        self.mem_addr_high_txt = [None]*4
        pcap_sizer.AddMany([(wx.StaticText(pcap_panel, label="Interface", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(pcap_panel, label="Pcap File", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(pcap_panel, label="Replay Cnt", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(pcap_panel, label="Replay Cnt Display", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(pcap_panel, label="Mem_addr_low", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(pcap_panel, label="Mem_addr_high", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(4):
            self.pcap_file_btn[i] = wx.Button(pcap_panel, wx.ID_ANY, "Select Pcap File", style=wx.ALIGN_CENTER, name=str(i))
            self.replay_cnt_input[i] = wx.lib.intctrl.IntCtrl(pcap_panel, min=0, max=(int('0xffffffff', 16)), name=str(i))
            self.replay_cnt_txt[i] = wx.StaticText(pcap_panel, wx.ID_ANY, label='0', style=wx.ALIGN_CENTER)
            self.mem_addr_low_txt[i] = wx.StaticText(pcap_panel, wx.ID_ANY, label='0', style=wx.ALIGN_CENTER)
            self.mem_addr_high_txt[i] = wx.StaticText(pcap_panel, wx.ID_ANY, label='0', style=wx.ALIGN_CENTER)
            pcap_sizer.AddMany([(wx.StaticText(pcap_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.pcap_file_btn[i], 0, wx.EXPAND),
                (self.replay_cnt_input[i], 0, wx.EXPAND),
                (self.replay_cnt_txt[i], 0, wx.EXPAND),
                (self.mem_addr_low_txt[i], 0, wx.EXPAND),
                (self.mem_addr_high_txt[i], 0, wx.EXPAND)])

        # Rate Limiter panel
        rate_limiter_title = wx.StaticText(self, label="RATE LIMITER", style=wx.ALIGN_CENTER)
        rate_limiter_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        rate_limiter_title.SetBackgroundColour('GRAY')
        rate_limiter_panel = wx.Panel(self)
        rate_limiter_panel.SetBackgroundColour('WHEAT')
        rate_limiter_sizer = wx.GridSizer(5, 5, 10, 10)
        rate_limiter_panel.SetSizer(rate_limiter_sizer)
        self.rate_input = [None]*4
        self.rate_txt = [None]*4
        self.rate_limiter_enable_toggle = [None]*4
        self.rate_limiter_reset_button = [None]*4
        rate_limiter_sizer.AddMany([(wx.StaticText(rate_limiter_panel, label="Interface", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(rate_limiter_panel, label="Rate Input", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(rate_limiter_panel, label="Rate Display", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(rate_limiter_panel, label="Enable", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(rate_limiter_panel, label="Reset", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(4):
            self.rate_input[i] = wx.Slider(rate_limiter_panel, value=0, minValue=0, maxValue=40, style=wx.SL_HORIZONTAL, name=str(i))
            self.rate_txt[i] = wx.StaticText(rate_limiter_panel, wx.ID_ANY, label='0', style=wx.ALIGN_CENTER)
            self.rate_limiter_enable_toggle[i] = wx.ToggleButton(rate_limiter_panel, wx.ID_ANY, label="Enable", style=wx.ALIGN_CENTER, name=str(i))
            self.rate_limiter_reset_button[i] = wx.Button(rate_limiter_panel, wx.ID_ANY, label="Reset", style=wx.ALIGN_CENTER, name=str(i))
            rate_limiter_sizer.AddMany([(wx.StaticText(rate_limiter_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.rate_input[i], 0, wx.EXPAND),
                (self.rate_txt[i], 0, wx.EXPAND),
                (self.rate_limiter_enable_toggle[i], 0, wx.EXPAND),
                (self.rate_limiter_reset_button[i], 0, wx.EXPAND)])

        # Delay panel
        delay_title = wx.StaticText(self, label="INTER PACKET DELAY", style=wx.ALIGN_CENTER)
        delay_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        delay_title.SetBackgroundColour('GRAY')
        delay_panel = wx.Panel(self)
        delay_panel.SetBackgroundColour('WHEAT')
        delay_sizer = wx.GridSizer(5, 6, 10, 10)
        delay_panel.SetSizer(delay_sizer)
        self.use_reg_toggle = [None]*4
        self.delay_input = [None]*4
        self.delay_txt = [None]*4
        self.delay_enable_toggle = [None]*4
        self.delay_reset_button = [None]*4
        delay_sizer.AddMany([(wx.StaticText(delay_panel, label="Interface", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(delay_panel, label="Delay Source", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(delay_panel, label="Delay Reg Input", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(delay_panel, label="Delay Reg Display", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(delay_panel, label="Enable", style=wx.ALIGN_CENTER), 0, wx.EXPAND),
            (wx.StaticText(delay_panel, label="Reset", style=wx.ALIGN_CENTER), 0, wx.EXPAND)])
        for i in range(4):
            self.use_reg_toggle[i] = wx.ToggleButton(delay_panel, wx.ID_ANY, label="Use Reg", style=wx.ALIGN_CENTER, name=str(i))
            self.delay_input[i] = wx.lib.intctrl.IntCtrl(delay_panel, min=0, max=(int('0xffffffff', 16)), name=str(i))
            self.delay_txt[i] = wx.StaticText(delay_panel, wx.ID_ANY, label='0', style=wx.ALIGN_CENTER)
            self.delay_enable_toggle[i] = wx.ToggleButton(delay_panel, wx.ID_ANY, label="Enable", style=wx.ALIGN_CENTER, name=str(i))
            self.delay_reset_button[i] = wx.Button(delay_panel, wx.ID_ANY, label="Reset", style=wx.ALIGN_CENTER, name=str(i))
            delay_sizer.AddMany([(wx.StaticText(delay_panel, label=str(i), style=wx.ALIGN_CENTER), 0, wx.EXPAND),
                (self.use_reg_toggle[i], 0, wx.EXPAND),
                (self.delay_input[i], 0, wx.EXPAND),
                (self.delay_txt[i], 0, wx.EXPAND),
                (self.delay_enable_toggle[i], 0, wx.EXPAND),
                (self.delay_reset_button[i], 0, wx.EXPAND)])


        # Logger
        logger_title = wx.StaticText(self, label="LOGGER", style=wx.ALIGN_CENTER)
        logger_title.SetFont(wx.Font(15, wx.DECORATIVE, wx.NORMAL, wx.BOLD))
        logger_title.SetBackgroundColour('GRAY')
        self.logger = wx.TextCtrl(self, style=wx.TE_MULTILINE|wx.TE_READONLY)

        # Setting up the menu.
        console_menu = wx.Menu()
        start_replay_menu = console_menu.Append(wx.ID_ANY, "Replay", "Start Replaying")
        stop_replay_menu = console_menu.Append(wx.ID_ANY, 'Stop', 'Stop Replaying')
        reset_pcap_menu = console_menu.Append(wx.ID_ANY, 'Reset Pcap Engine', 'Reset Pcap Engine')  
 
        # Creating the menubar.
        menuBar = wx.MenuBar()
        menuBar.Append(console_menu, "&Console")
        self.SetMenuBar(menuBar)  # Adding the MenuBar to the Frame content.

        self.Bind(wx.EVT_MENU, self.on_start_replay, start_replay_menu)
        self.Bind(wx.EVT_MENU, self.on_stop_replay, stop_replay_menu)
        self.Bind(wx.EVT_MENU, self.on_reset_pcap, reset_pcap_menu)
        for i in range(4):
            self.Bind(wx.EVT_BUTTON, self.on_select_pcap_file, self.pcap_file_btn[i])
            self.Bind(wx.EVT_TEXT, self.on_replay_cnt_change, self.replay_cnt_input[i])
            self.Bind(wx.EVT_SCROLL, self.on_rate_change, self.rate_input[i])
            self.Bind(wx.EVT_TOGGLEBUTTON, self.on_rate_limiter_enable, self.rate_limiter_enable_toggle[i])
            self.Bind(wx.EVT_BUTTON, self.on_rate_limiter_reset, self.rate_limiter_reset_button[i])
            self.Bind(wx.EVT_TOGGLEBUTTON, self.on_delay_use_reg, self.use_reg_toggle[i])
            self.Bind(wx.EVT_TEXT, self.on_delay_change, self.delay_input[i])
            self.Bind(wx.EVT_TOGGLEBUTTON, self.on_delay_enable, self.delay_enable_toggle[i])
            self.Bind(wx.EVT_BUTTON, self.on_delay_reset, self.delay_reset_button[i])

 
        # Use some sizers to see layout options
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.sizer.Add(pcap_title, 0.5, wx.EXPAND)
        self.sizer.Add(pcap_panel, 4, wx.EXPAND)
        self.sizer.Add(rate_limiter_title, 0.5, wx.EXPAND)
        self.sizer.Add(rate_limiter_panel, 4, wx.EXPAND)
        self.sizer.Add(delay_title, 0.5, wx.EXPAND)
        self.sizer.Add(delay_panel, 4, wx.EXPAND)
        self.sizer.Add(logger_title, 0.5, wx.EXPAND)
        self.sizer.Add(self.logger, 2, wx.EXPAND)
   
        #Layout sizers
        self.SetSizer(self.sizer)
        self.SetAutoLayout(1)
        self.sizer.Fit(self)
        self.Show()

    def readings_init(self):
        for i in range(4):
            iface = 'nf'+str(i)
            self.replay_cnt_input[i].SetValue(self.pcap_engine.replay_cnt[i])
            self.replay_cnt_txt[i].SetLabel(str(self.pcap_engine.replay_cnt[i]))
            self.mem_addr_low_txt[i].SetLabel(hex(self.pcap_engine.mem_addr_low[i]))
            self.mem_addr_high_txt[i].SetLabel(hex(self.pcap_engine.mem_addr_high[i]))
            self.rate_input[i].SetValue(self.rate_limiters[i].rate)
            self.rate_txt[i].SetLabel(self.rate_limiters[i].to_string(self.average_pkt_len[iface], self.average_word_cnt[iface]))
            self.rate_limiter_enable_toggle[i].SetValue(self.rate_limiters[i].enable)
            self.delay_input[i].SetValue(self.delays[i].delay*1000000000/160000000)
            self.delay_txt[i].SetLabel(self.delays[i].to_string())
            self.delay_enable_toggle[i].SetValue(self.delays[i].enable)
            self.use_reg_toggle[i].SetValue(self.delays[i].use_reg)
            if self.delays[i].use_reg == True:
                self.use_reg_toggle[i].SetLabel('Using register')
            else:
                self.use_reg_toggle[i].SetLabel('Using timestamp')
        #self.log(self.delay_header_extractor.get_status())

    def log(self, text):
        self.logger.AppendText(str(datetime.datetime.now())+': '+text+'\n')

    def on_start_replay(self, event):
        self.pcap_engine.run()
        self.log('Started replaying.')

    def on_stop_replay(self, event):
        self.pcap_engine.stop_replay()
        self.log('Stopped replaying.')

    def on_reset_pcap(self, event):
        self.pcap_engine.clear()
        self.average_pkt_len = {'nf0':1500, 'nf1':1500, 'nf2':1500, 'nf3':1500}
        self.average_word_cnt = {'nf0':47, 'nf1':47, 'nf2':47, 'nf3':47}
        self.pkts_loaded = {'nf0':0, 'nf1':0, 'nf2':0, 'nf3':0}
        self.readings_init()
        for i in range(4):
            self.pcap_file_btn[i].SetLabel('Select Pcap File')
        self.log('Reset Pcap Engine.')

    def on_select_pcap_file(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        dlg = wx.FileDialog(self, "Choose a file", "", "", "*.cap", wx.OPEN)
        if dlg.ShowModal() == wx.ID_OK:
            self.pcaps['nf'+str(iface)] = os.path.join(dlg.GetDirectory(), dlg.GetFilename())
            self.pcap_file_btn[iface].SetLabel(dlg.GetFilename())
        else:
            self.pkts_loaded['nf'+str(iface)] = 0
            self.average_pkt_len['nf'+str(iface)] = 1500
            self.average_word_cnt['nf'+str(iface)] = 47
            self.pcaps.pop('nf'+str(iface), 0)
            self.pcap_file_btn[iface].SetLabel('Select Pcap File')
        
        result = self.pcap_engine.load_pcap(self.pcaps)
        self.average_pkt_len.update(result['average_pkt_len'])
        self.average_word_cnt.update(result['average_word_cnt'])
        self.pkts_loaded.update(result['pkts_loaded'])
        self.readings_init()
        self.log('Selected Pcap file for port '+str(iface))
        for iface in self.pkts_loaded:
            self.log('Loaded %d packets for %s.' % (self.pkts_loaded[iface], iface))

    def on_replay_cnt_change(self, event):
        spin_ctrl = event.GetEventObject()
        iface = int(spin_ctrl.GetName())
        replay_cnt = spin_ctrl.GetValue()
        self.pcap_engine.replay_cnt[iface] = replay_cnt
        self.pcap_engine.set_replay_cnt()
        self.replay_cnt_txt[iface].SetLabel(str(self.pcap_engine.replay_cnt[iface]))
        self.log('Replay count changed for port '+str(iface))

    def on_rate_change(self, event):
        slider = event.GetEventObject()
        iface = int(slider.GetName())
        rate = slider.GetValue()
        self.rate_limiters[iface].set_rate(rate)
        # This value is read back from hardware
        self.rate_txt[iface].SetLabel(self.rate_limiters[iface].to_string(self.average_pkt_len['nf'+str(iface)], self.average_word_cnt['nf'+str(iface)]))
        self.log('Rate changed for port '+str(iface))

    def on_rate_limiter_enable(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        enable = button.GetValue()
        self.rate_limiters[iface].set_enable(enable)
        # This value is read back from hardware
        button.SetValue(self.rate_limiters[iface].enable)
        self.log('Rate limiter enable changed for port '+str(iface))

    def on_rate_limiter_reset(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        self.rate_limiters[iface].set_reset(True)
        # This value is read back from hardware
        #button.SetValue(self.rate_limiters[iface].reset)
        self.readings_init()
        self.rate_limiters[iface].set_reset(False)
        self.log('Rate limiter reset changed for port '+str(iface))

    def on_delay_change(self, event):
        spin_ctrl = event.GetEventObject()
        iface = int(spin_ctrl.GetName())
        delay = spin_ctrl.GetValue()
        self.delays[iface].set_delay(delay)
        # This value is read back from hardware
        self.delay_txt[iface].SetLabel(self.delays[iface].to_string())
        self.log('Delay value changed for port '+str(iface))

    def on_delay_enable(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        enable = button.GetValue()
        self.delays[iface].set_enable(enable)
        # This value is read back from hardware
        button.SetValue(self.delays[iface].enable)
        self.log('Delay enable changed for port '+str(iface))

    def on_delay_reset(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        self.delays[iface].set_reset(True)
        # This value is read back from hardware
        #button.SetValue(self.delays[iface].reset)
        self.readings_init()
        self.delays[iface].set_reset(False)
        self.log('Delay reset changed for port '+str(iface))

    def on_delay_use_reg(self, event):
        button = event.GetEventObject()
        iface = int(button.GetName())
        use_reg = button.GetValue()
        self.delays[iface].set_use_reg(use_reg)
        # This value is read back from hardware
        button.SetValue(self.delays[iface].use_reg)
        if self.delays[iface].use_reg == True:
            self.use_reg_toggle[iface].SetLabel('Using register')
        else:
            self.use_reg_toggle[iface].SetLabel('Using timestamp')
        self.log('Delay use reg changed for port '+str(iface))


app = wx.App(False)
frame = MainWindow()
app.MainLoop()

