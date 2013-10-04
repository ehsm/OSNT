import os
from monitor import *
import wx

class MainWindow(wx.Frame):
    def __init__(self, parent, title):
        self.dirname=''
        wx.Frame.__init__(self, parent, title=title, size=(-1,-1))

        # Stats display panel
        stats_panel = wx.Panel(self)
        stats_sizer = wx.GridSizer(5, 7, 5, 5)
        stats_sizer.AddMany([(wx.StaticText(stats_panel, label="Port"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Pkt Cnt"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Byte Cnt"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="Vlan Cnt"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="IP Cnt"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="UDP Cnt"), 0, wx.EXPAND),
            (wx.StaticText(stats_panel, label="TCP Cnt"), 0, wx.EXPAND)])
        for i in range(4):
            ports_label[i] = wx.StaticText(stats_panel, label=str(i))




        self.control = wx.TextCtrl(self, style=wx.TE_MULTILINE)
   
        # Setting up the menu.
        filemenu= wx.Menu()
        menuOpen = filemenu.Append(wx.ID_OPEN, "&Open"," Open a file to edit")
        menuAbout= filemenu.Append(wx.ID_ABOUT, "&About"," Information about this program")
        menuExit = filemenu.Append(wx.ID_EXIT,"E&xit"," Terminate the program")
   
        # Creating the menubar.
        menuBar = wx.MenuBar()
        menuBar.Append(filemenu,"&File") # Adding the "filemenu" to the MenuBar
        self.SetMenuBar(menuBar)  # Adding the MenuBar to the Frame content.
   
        # Events.
        self.Bind(wx.EVT_MENU, self.OnOpen, menuOpen)
        self.Bind(wx.EVT_MENU, self.OnExit, menuExit)
        self.Bind(wx.EVT_MENU, self.OnAbout, menuAbout)
   
        self.sizer2 = wx.BoxSizer(wx.HORIZONTAL)
        self.buttons = []
        for i in range(0, 6):
            self.buttons.append(wx.Button(self, -1, "Button &"+str(i)))
            self.sizer2.Add(self.buttons[i], 1, wx.EXPAND)
   
        # Use some sizers to see layout options
        self.sizer = wx.BoxSizer(wx.VERTICAL)
        self.sizer.Add(self.control, 1, wx.EXPAND)
        self.sizer.Add(self.sizer2, 0, wx.EXPAND)
   
        #Layout sizers
        self.SetSizer(self.sizer)
        self.SetAutoLayout(1)
        self.sizer.Fit(self)
        self.Show()
   
    def OnAbout(self,e):
        # Create a message dialog box
        dlg = wx.MessageDialog(self, " A sample editor \n in wxPython", "About Sample Editor", wx.OK)
        dlg.ShowModal() # Shows it
        dlg.Destroy() # finally destroy it when finished.
   
    def OnExit(self,e):
        self.Close(True)  # Close the frame.
   
    def OnOpen(self,e):
        """ Open a file"""
        dlg = wx.FileDialog(self, "Choose a file", self.dirname, "", "*.*", wx.OPEN)
        if dlg.ShowModal() == wx.ID_OK:
            self.filename = dlg.GetFilename()
            self.dirname = dlg.GetDirectory()
            f = open(os.path.join(self.dirname, self.filename), 'r')
            self.control.SetValue(f.read())
            f.close()
        dlg.Destroy()
   
app = wx.App(False)
frame = MainWindow(None, "OSNT Monitor")
app.MainLoop()

