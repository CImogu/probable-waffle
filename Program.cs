using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;

using System;
public class JoyconManger {
    public bool EnableIMU = false; // was originally true
    public bool EnableLocalize = false; // was originally true

    private const ushort vendor_id = 0x57e;
    private const ushort vendor_id_ = 0x057e;
    private const ushort product_l = 0x2006;
    private const ushort product_r = 0x2007;

    public List<Joycon> j = new List<Joycon>(); //Array of all connected Joy-Cons

    static void Main() {
        JoyconManger manager = new JoyconManger();
		manager.Awake();

        manager.Start();
	}

    public static JoyconManger Instance { get; private set; }

    void Awake() {
        // if (instance != null) return null;
        Instance = this;
        int i = 0;
        j = new List<Joycon>();
        bool isLeft = false;
        HIDapi.hid_init();

        IntPtr ptr = HIDapi.hid_enumerate(vendor_id, 0x0);
		IntPtr top_ptr = ptr; 

        if (ptr == IntPtr.Zero)
		{
			ptr = HIDapi.hid_enumerate(vendor_id_, 0x0);
			if (ptr == IntPtr.Zero)
			{ 
				HIDapi.hid_free_enumeration(ptr);
				Console.WriteLine ("No Joy-Cons found!");
			}
		}

        hid_device_info enumerate;
		while (ptr != IntPtr.Zero) {
            enumerate = (hid_device_info)Marshal.PtrToStructure(ptr, typeof(hid_device_info));

			Console.WriteLine  (enumerate.product_id);
				if (enumerate.product_id == product_l || enumerate.product_id == product_r) {
					if (enumerate.product_id == product_l) {
						isLeft = true;
						Console.WriteLine  ("Left Joy-Con connected.");
					} else if (enumerate.product_id == product_r) {
						isLeft = false;
						Console.WriteLine  ("Right Joy-Con connected.");
					} else {
						Console.WriteLine  ("Non Joy-Con input device skipped.");
					}
					IntPtr handle = HIDapi.hid_open_path (enumerate.path);
					HIDapi.hid_set_nonblocking (handle, 1);
					j.Add (new Joycon (handle, EnableIMU, EnableLocalize & EnableIMU, 0.05f, isLeft));
					++i;
				}
				ptr = enumerate.next;
			}
		HIDapi.hid_free_enumeration (top_ptr);
    }

    void Start() {
        for (int i = 0; i < j.Count; ++i)
		{
			Console.WriteLine  (i);
			Joycon jc = j [i];
			byte LEDs = 0x0;
			LEDs |= (byte)(0x1 << i);
			jc.Attach (leds_: LEDs);
			jc.Begin ();
		}
    } 

    void Update () {
        for (int i = 0; i < j.Count; ++i)
		{
			j[i].Update();
		}
    }

    void OnApplicationQuit(){
        for (int i = 0; i < j.Count; ++i)
		{
			j[i].Detach ();
		}
    }
}
