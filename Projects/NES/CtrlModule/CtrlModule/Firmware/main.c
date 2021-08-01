#include "host.h"

#include "osd.h"
#include "keyboard.h"
#include "menu.h"
#include "ps2.h"
#include "minfat.h"
#include "spi.h"
#include "fileselector.h"

fileTYPE file;

int Load_filetype = 0;

int OSD_Puts(char *str)
{
	int c;
	while((c=*str++))
		OSD_Putchar(c);
	return(1);
}

/*
void TriggerEffect(int row)
{
	int i,v;
	Menu_Hide();
	for(v=0;v<=16;++v)
	{
		for(i=0;i<4;++i)
			PS2Wait();

		HW_HOST(REG_HOST_SCALERED)=v;
		HW_HOST(REG_HOST_SCALEGREEN)=v;
		HW_HOST(REG_HOST_SCALEBLUE)=v;
	}
	Menu_Show();
}
*/

void Delay(int repeat_delay) // when repeat = 100 delay is around 8ms @81Mhz core clk 
{
	int count, repeat;

	for (repeat = 0; repeat<repeat_delay; repeat++)
	{
		count=16384;
		while(count) // delay some cycles
		{ 
			count--;
		} 
	}
}


void Reset(int row) // row is the line number in menu
{
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_RESET|HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Reset host core
	Delay(600);
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Release reset
}

void Select(int row) // row is the line number in menu
{
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_SELECT|HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Send select
	Delay(600);
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Release select
}

void Start(int row) // row is the line number in menu
{
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_START|HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Send start	
	Delay(600);
	HW_HOST(REG_HOST_CONTROL)=HOST_CONTROL_DIVERT_KEYBOARD|HOST_CONTROL_DIVERT_SDCARD; // Release start
}

void LoadFileType_0(int row)
{
	Load_filetype = 0;
	FileSelector_Show(row);
}

void LoadFileType_2(int row)
{
	Load_filetype = 2;
	FileSelector_Show(row);
}

void LoadFileType_3(int row)
{
	Load_filetype = 3;
	FileSelector_Show(row);
}

static struct menu_entry topmenu[]; // Forward declaration.
/*
// RGB scaling submenu
static struct menu_entry rgbmenu[]=
{
	{MENU_ENTRY_SLIDER,"Red",MENU_ACTION(16)},
	{MENU_ENTRY_SLIDER,"Green",MENU_ACTION(16)},
	{MENU_ENTRY_SLIDER,"Blue",MENU_ACTION(16)},
	{MENU_ENTRY_SUBMENU,"Exit",MENU_ACTION(topmenu)},
	{MENU_ENTRY_NULL,0,0}
};
*/

static char *diskside_manual_labels[]=
{
	"Auto side",
	"Auto side + 1",
	"Auto side + 2",
	"Auto side + 3"
};

static char *scanlines_scale_labels[]=
{
	"Scanlines off",
	"Scanlines 25%",
	"Scanlines 50%",
	"Scanlines 75%"
};

static char *palette_labels[]=
{
	"Smooth palette",
	"NTSC unsaturatedV6 palette",
	"FCEUX palette",
	"NES classic palette",
	"Composite direct palette",
	"PC-10 palette",
	"PVM palette",
	"Wavebeam palette"
};

// Our toplevel menu
static struct menu_entry topmenu[] =
{
	{MENU_ENTRY_CALLBACK,"Reset NES",MENU_ACTION(&Reset)},
//	{MENU_ENTRY_SUBMENU,"RGB scaling \x10",MENU_ACTION(rgbmenu)},
	{MENU_ENTRY_TOGGLE,"Scanlines (OSD)",MENU_ACTION(0)},           // 0 is the bit position in menu_toggle_bits
	{MENU_ENTRY_TOGGLE,"Hq2x filter",MENU_ACTION(1)},               // 1 is the bit position in menu_toggle_bits
	{MENU_ENTRY_TOGGLE,"Forced scandoubler",MENU_ACTION(2)},        // 2 is the bit position in menu_toggle_bits
	{MENU_ENTRY_TOGGLE,"Hide overscan",MENU_ACTION(3)},             // 3 is the bit position in menu_toggle_bits
	{MENU_ENTRY_TOGGLE,"Auto-swap/Eject FDS disk",MENU_ACTION(4)},  // 4 is the bit position in menu_toggle_bits
	{MENU_ENTRY_CYCLE,(char *)diskside_manual_labels,MENU_ACTION(4)},  // 4 is the number of elements
	{MENU_ENTRY_CYCLE,(char *)scanlines_scale_labels,MENU_ACTION(4)},  // 4 is the number of elements
	{MENU_ENTRY_CYCLE,(char *)palette_labels,MENU_ACTION(8)},          // 8 is the number of elements
//	{MENU_ENTRY_CALLBACK,"Load ROM \x10",MENU_ACTION(&FileSelector_Show)},
//	{MENU_ENTRY_CALLBACK,"Load FDS Bios \x10",MENU_ACTION(&FileSelector_Show)},
	{MENU_ENTRY_CALLBACK,"Load NES ROM \x10",MENU_ACTION(&LoadFileType_0)},
	{MENU_ENTRY_CALLBACK,"Load Powerpak FDS Bios \x10",MENU_ACTION(&LoadFileType_2)},
	{MENU_ENTRY_CALLBACK,"Load FDS ROM \x10",MENU_ACTION(&LoadFileType_3)},
	{MENU_ENTRY_CALLBACK,"Exit",MENU_ACTION(&Menu_Hide)},
	{MENU_ENTRY_NULL,0,0}
};


// An error message
static struct menu_entry loadfailed[]=
{
	{MENU_ENTRY_SUBMENU,"ROM loading failed",MENU_ACTION(loadfailed)},
	{MENU_ENTRY_SUBMENU,"OK",MENU_ACTION(&topmenu)},
	{MENU_ENTRY_NULL,0,0}
};

static int LoadROM( const char *filename )
{
	int result = 0;
	int opened;
		
	// ResetLoader
	HW_HOST( REG_HOST_CONTROL ) = HOST_CONTROL_LOADER_RESET | HOST_CONTROL_RESET | HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD;
	Delay(100);	
	HW_HOST( REG_HOST_CONTROL ) = HOST_CONTROL_RESET | HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD;

	if(( opened = FileOpen( &file, filename )))
	{
		int filesize = file.size;
		unsigned int c = 0;
		int bits;

		HW_HOST( REG_HOST_FILETYPE ) = Load_filetype;
		HW_HOST( REG_HOST_ROMSIZE ) = file.size;
		
		bits = 0;
		c = filesize - 1;
		
		while( c )
		{
			++bits;
			c >>= 1;
		}
		bits -= 9;

		result = 1;

		while( filesize > 0 )
		{
			OSD_ProgressBar( c, bits );
			
			if( FileRead( &file, sector_buffer ))
			{
				int i;
				int *p = ( int * ) &sector_buffer;
				
				for(i = 0; i < 512; i+=4 )
				{
					unsigned int t = *p++;
					HW_HOST( REG_HOST_BOOTDATA ) = t;
					filesize -= 4;
					if (filesize <= 0) break;
				}
			}
			else // read error
			{
				result = 0;
				break;
			}
			
			FileNextSector( &file );
			++c;
		}
	}
	
	HW_HOST( REG_HOST_CONTROL ) = HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD; // Release host reset
	
	if( result ) 
	{
		Menu_Set( topmenu );
		Menu_Hide();
		Reset(0);
	}
	else
		Menu_Set( loadfailed );
	
	return( result );
}


int main( int argc, char **argv )
{
	int i;
	int dipsw = 0;

	// Put the host core in reset and take control of the SD card while we initialise...
	HW_HOST( REG_HOST_CONTROL ) = HOST_CONTROL_RESET | HOST_CONTROL_DIVERT_SDCARD;

	PS2Init();
	EnableInterrupts();

	OSD_Clear();
	
	for( i = 0; i < 4; ++i )
	{
		PS2Wait();	// Wait for an interrupt - most likely VBlank, but could be PS/2 keyboard
		OSD_Show( 1 );	// Call this over a few frames to let the OSD figure out where to place the window.
	}
	
	OSD_Puts( "Initializing SD card\n" );

	if( !FindDrive() )
		return( 0 );

//	OSD_Puts("Loading initial ROM...\n");
//	LoadROM("PIC1    RAW");

	FileSelector_SetLoadFunction( LoadROM );
	
	Menu_Set( topmenu );
	Menu_Show();

	while( 1 )
	{
		struct menu_entry *m;
		int visible;
		
		HandlePS2RawCodes();
		
		visible = Menu_Run();

		dipsw  = MENU_CYCLE_VALUE ( &topmenu[ 6 ] ) <<10; // Take the value of the scanlines intensity cycle menu entry (line 5).
		                                                  // and put on dipsw[11:10] (2 bits assuming max value is 3)

		dipsw |= MENU_CYCLE_VALUE ( &topmenu[ 7 ] ) << 3; // Take the value of the scanlines intensity cycle menu entry (line 6).
		                                                  // and put on dipsw[4:3] (2 bits assuming max value is 3)

		dipsw |= MENU_CYCLE_VALUE ( &topmenu[ 8 ] ) << 6; // Take the value of the palette cycle menu entry (line 7).
		                                                  // and put on dipsw[8:6] (3 bits assuming max value is 7)
	
		if( MENU_TOGGLE_VALUES & 1 ) 
 			dipsw |= 1 ;	           // Add in the scanlines bit on dipsw[0]
		
		if( MENU_TOGGLE_VALUES & 2 )
			dipsw |= 2;	           // Add in the HQ2X bit on dipsw[1]
		
		if( MENU_TOGGLE_VALUES & 4 )
			dipsw |= 4;	           // Add in forced scandoubler bit on dipsw[2]

		if( MENU_TOGGLE_VALUES & 8 )
			dipsw |= 32;	           // Add in hide_overscan bit on dipsw[5]

		if( MENU_TOGGLE_VALUES & 16 )
			dipsw |= 512;	           // Add in swap_fds_disk bit on dipsw[9]

		HW_HOST( REG_HOST_SW ) = dipsw;	// Send the new values to the hardware.
		
//		HW_HOST(REG_HOST_SCALERED)=MENU_SLIDER_VALUE(&rgbmenu[0]);
//		HW_HOST(REG_HOST_SCALEGREEN)=MENU_SLIDER_VALUE(&rgbmenu[1]);
//		HW_HOST(REG_HOST_SCALEBLUE)=MENU_SLIDER_VALUE(&rgbmenu[2]);

		// If the menu's visible, prevent keystrokes reaching the host core.
		HW_HOST( REG_HOST_CONTROL )=( visible ?
									HOST_CONTROL_DIVERT_KEYBOARD | HOST_CONTROL_DIVERT_SDCARD :
									HOST_CONTROL_DIVERT_SDCARD ); // Maintain control of the SD card so the file selector can work.
																 // If the host needs SD card access then we would release the SD
																 // card here, and not attempt to load any further files.
	}
	return( 0 );
}
