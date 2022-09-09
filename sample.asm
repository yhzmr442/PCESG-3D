;///////////////////////////
;////////    EQU    ////////
;///////////////////////////
;---------------------
		INCLUDE	"poly_equ.asm"

shipMoveQuantity	.equ	8
ringMoveQuantity	.equ	16
ringRotationQuantity	.equ	4
buildingMoveQuantity	.equ	16
objectFrontZ		.equ	128
objectBackZ		.equ	2048
screenFrameMax		.equ	64


;/////////////////////////////
;////////    MACRO    ////////
;/////////////////////////////
;---------------------
		INCLUDE	"poly_macro.asm"


;///////////////////////////
;////////    RAM    ////////
;///////////////////////////
		.zp
;---------------------
		INCLUDE	"poly_dszp.asm"

		.bss
;---------------------
modelX		.ds	2
modelY		.ds	2

modelRing0Z	.ds	2
modelRing1Z	.ds	2
modelRingRZ	.ds	1

modelBuilding0X	.ds	2
modelBuilding1X	.ds	2

modelBuilding0Z	.ds	2
modelBuilding1Z	.ds	2

;---------------------
		INCLUDE	"poly_ds.asm"


;///////////////////////////
;////////    ROM    ////////
;///////////////////////////
;----------------------------
;--------    CODE    --------
;----------------------------
		.code

		.bank	0
		.org	$E000

;----------------------------
main:
;
;set polygon function bank
		lda	#polygonFunctionBank
		tam	#polygonFunctionMap

;initialize polygon function
		jsr	initializePolygonFunction

;clear VRAM buffer
		movw	<argw0, #$5000
		movw	<argw1, #vramClearData
		ldy	#VDC1
		jsr	clearVramBuffer

		ldy	#VDC2
		jsr	clearVramBuffer

;set all palettes
		movw	<argw0, #paletteData
		jsr	setAllPalette

;set all polygon colors
		movw	<argw0, #polygonColor
		jsr	setAllPolygonColor

;set screen center
		ldx	#128
		ldy	#96
		jsr	setScreenCenter

;set world data:
		stzw	<eyeTranslationX
		stzw	<eyeTranslationY
		stzw	<eyeTranslationZ

		stz	<eyeRotationX
		stz	<eyeRotationY
		stz	<eyeRotationZ
		mov	<eyeRotationSelect, #$12

;initialize vsync, auto-increment, screen display and hide
		jsr	initializeScreenVsync

;initialize model data
		stzw	modelX
		stzw	modelY
		movw	modelRing0Z, #1024
		movw	modelRing1Z, #2048

		stz	modelRingRZ

		movw	modelBuilding0X, #-256
		movw	modelBuilding1X, #256

		movw	modelBuilding0Z, #512
		movw	modelBuilding1Z, #1536

;vsync interrupt start
		cli

.mainLoop:
;polygon and sprite initialize processing
;initialize buffer
		jsr	initializePolygonBuffer

;clear sat buffer
		jsr	clearSatBuffer

;game process
;don't let interruptions be blocked for a long time
;check pad:
;pad up
		bbr4	<padNow, .checkPadDown
		addw	modelY, #shipMoveQuantity

.checkPadDown:
;pad down
		bbr6	<padNow, .checkPadLeft
		subw	modelY, #shipMoveQuantity

.checkPadLeft:
;pad left
		bbr7	<padNow, .checkPadRight
		subw	modelX, #shipMoveQuantity

.checkPadRight:
;pad right
		bbr5	<padNow, .checkPadEnd
		addw	modelX, #shipMoveQuantity
.checkPadEnd:

;set polygon color index
		cla
		jsr	setPolygonColorIndex

;set model
;ship
		movw	<translationX, modelX
		stzw	<eyeTranslationX

		cmpw	modelX, #screenFrameMax
		bmi	.jp0
		subw	<eyeTranslationX, modelX, #screenFrameMax
		bra	.jp1
.jp0:
		cmpw	modelX, #-screenFrameMax
		bpl	.jp1
		addw	<eyeTranslationX, modelX, #screenFrameMax
.jp1:

		movw	<translationY, modelY
		stzw	<eyeTranslationY

		cmpw	modelY, #screenFrameMax
		bmi	.jp2
		subw	<eyeTranslationY, modelY, #screenFrameMax
		bra	.jp3
.jp2:
		cmpw	modelY, #-screenFrameMax
		bpl	.jp3
		addw	<eyeTranslationY, modelY, #screenFrameMax
.jp3:

		movw	<translationZ, #200

		mov	<rotationX, #0
		mov	<rotationY, #0
		mov	<rotationZ, #0
		mov	<rotationSelect, #$12

		movw	<modelAddress, #modelData0

		jsr	setModelRotation

;ring
		clx
.loop0:
		movw	<translationX, #0
		movw	<translationY, #0
		movwzpx	<translationZ, modelRing0Z, x

		mov	<rotationX, #0
		mov	<rotationY, #0
		mov	<rotationZ, modelRingRZ
		mov	<rotationSelect, #$12

		movw	<modelAddress, #modelData1

		jsr	setModelRotation

		subw2	modelRing0Z, x, #ringMoveQuantity
		cmpw2	modelRing0Z, x, #objectFrontZ
		bcs	.jp4
		movw2	modelRing0Z, x, #objectBackZ

.jp4:
		add	modelRingRZ, #ringRotationQuantity

		inx
		inx
		cpx	#4
		bne	.loop0

;building
		clx
.loop1:
		movwzpx	<translationX, modelBuilding0X, x
		movw	<translationY, #-128
		movwzpx	<translationZ, modelBuilding0Z, x

		mov	<rotationX, #0
		mov	<rotationY, #0
		mov	<rotationZ, #0
		mov	<rotationSelect, #$12

		movw	<modelAddress, #modelData2

		jsr	setModelRotation

		subw2	modelBuilding0Z, x, #buildingMoveQuantity
		cmpw2	modelBuilding0Z, x, #objectFrontZ
		bcs	.jp5
		movw2	modelBuilding0Z, x, #objectBackZ
.jp5:

		inx
		inx
		cpx	#4
		bne	.loop1

;polygon and sprite output processing
;wait vsync and DMA
		jsr	waitScreenVsync

;put polygon
		jsr	putPolygonBuffer

;set SATB DMA
		jsr	setSatbDma

;set vsync flag
		jsr	setVsyncFlag

;jump mainloop
		jmp	.mainLoop


;----------------------------
vsyncFunction:
;The process here should be completed in a short time.
		jsr	getPadData
		rts


;----------------------------
_irq1:
;IRQ1 interrupt process
;ACK interrupt
		pha
		phx
		phy

;execute polygon function first
		jsr	irq1PolygonFunction

;call vsync function
		bbr5	<vdpStatus, .skip
		jsr	vsyncFunction

.skip:
		ply
		plx
		pla
		rti


;----------------------------
_reset:
;reset process
		sei

		csh

		cld

		ldx	#$FF
		txs

		lda	#$FF
		tam	#$00

		lda	#$F8
		tam	#$01

		stz	$2000
		tii	$2000, $2001, $1FFF

		stz	TIMER_CONTROL_REG

;disable interrupts
		lda	#%00000111
		sta	INTERRUPT_DISABLE_REG

;jump main
		jmp	main


;----------------------------
_irq2:
_nmi:
_timer:
;IRQ2 NMI interrupt process
		rti


;----------------------------
;--------    DATA    --------
;----------------------------
;----------------------------
modelData0
		MODEL_DATA	modelData0Polygon, 18, modelData0Vertex, 16

modelData0Polygon
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $19, $00, 0, 1, 2	;0 Front Bottom
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00, 0, 3, 1	;1 Front Right
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1E, $00, 0, 2, 3	;2 Front Left

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00, 3, 4, 1	;3 Middle Outer Right
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00, 3, 2, 4	;4 Middle Outer Left

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $09, $00, 5, 2, 1	;5 Middle Inner

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00, 1, 4, 5	;6 Middle Inner Right
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00, 4, 2, 5	;7 Middle Inner Left

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $09, $00, 7, 1, 6	;8 Right Wing Front
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00, 6, 8, 7	;9 Right Wing Right
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1D, $00, 1, 7, 8	;10 Right Wing Left
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00, 1, 8, 6	;11 Right Wing Top

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $09, $00, 2,10, 9	;12 Left Wing Front
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00, 2,11,10	;13 Left Wing Right
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1D, $00, 9,10,11	;14 Left Wing Left
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00, 9,11, 2	;15 Left Wing Top

		POLYGON_DATA	ATTR_NONE, $04, $0C, 1,12,13	;16 Right Wing

		POLYGON_DATA	ATTR_NONE, $04, $0C, 2,15,14	;17 Left Wing

modelData0Vertex
		VERTEX_DATA	   0, -10, 100	;0 Front
		VERTEX_DATA	  20, -10,   0	;1 Front Bottom Right
		VERTEX_DATA	 -20, -10,   0	;2 Front Bottom Left

		VERTEX_DATA	   0,  10,   0	;3 Front Middle Top

		VERTEX_DATA	   0,   0, -20	;4 Front Middle Back

		VERTEX_DATA	   0,   0,   0	;5 Front Middle Inner

		VERTEX_DATA	  40, -10,   0	;6 Right Wing Right
		VERTEX_DATA	  30, -20,   0	;7 Right Wing Bottom
		VERTEX_DATA	  70, -30, -50	;8 Right Wing Back

		VERTEX_DATA	 -40, -10,   0	;9 Left Wing Left
		VERTEX_DATA	 -30, -20,   0	;10 Left Wing Bottom
		VERTEX_DATA	 -70, -30, -50	;11 Left Wing Back

		VERTEX_DATA	  30, -20,  30;12 Right Wing Front
		VERTEX_DATA	  40,  40, -30;13 Right Wing Top

		VERTEX_DATA	 -30, -20,  30;14 Left Wing Front
		VERTEX_DATA	 -40,  40, -30;15 Left Wing Top


;----------------------------
modelData1
		MODEL_DATA	modelData1Polygon, 16, modelData1Vertex, 24

modelData1Polygon
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00, 0, 3, 4, 1	; 0
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $19, $00, 1, 4, 5, 2	; 1

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00, 3, 6, 7, 4	; 2
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00, 4, 7, 8, 5	; 3

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00, 6, 9,10, 7	; 4
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00, 7,10,11, 8	; 5

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1E, $00, 9,12,13,10	; 6
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1D, $00,10,13,14,11	; 7

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1E, $00,12,15,16,13	; 8
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1D, $00,13,16,17,14	; 9

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1C, $00,15,18,19,16	;10
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00,16,19,20,17	;11

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00,18,21,22,19	;12
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00,19,22,23,20	;13

		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1A, $00,21, 0, 1,22	;14
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $19, $00,22, 1, 2,23	;15

modelData1Vertex
		VERTEX_DATA	   0,-159,   0; 0
		VERTEX_DATA	   0,-143, -15; 1
		VERTEX_DATA	   0,-127,   0; 2

		VERTEX_DATA	 112,-112,   0; 3
		VERTEX_DATA	 101,-101, -15; 4
		VERTEX_DATA	  90, -90,   0; 5

		VERTEX_DATA	 159,   0,   0; 6
		VERTEX_DATA	 143,   0, -15; 7
		VERTEX_DATA	 127,   0,   0; 8

		VERTEX_DATA	 112, 112,   0; 9
		VERTEX_DATA	 101, 101, -15;10
		VERTEX_DATA	  90,  90,   0;11

		VERTEX_DATA	   0, 159,   0;12
		VERTEX_DATA	   0, 143, -15;13
		VERTEX_DATA	   0, 127,   0;14

		VERTEX_DATA	-112, 112,   0;15
		VERTEX_DATA	-101, 101, -15;16
		VERTEX_DATA	 -90,  90,   0;17

		VERTEX_DATA	-159,   0,   0;18
		VERTEX_DATA	-143,   0, -15;19
		VERTEX_DATA	-127,   0,   0;20

		VERTEX_DATA	-112,-112,   0;21
		VERTEX_DATA	-101,-101, -15;22
		VERTEX_DATA	 -90, -90,   0;23


;----------------------------
modelData2
		MODEL_DATA	modelData2Polygon, 4, modelData2Vertex, 8

modelData2Polygon
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1D, $00, 0, 3, 2, 1	; 0
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $1B, $00, 3, 7, 6, 2	; 1
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $19, $00, 2, 6, 5, 1	; 2
		POLYGON_DATA	ATTR_BACKDRAW_CXL, $19, $00, 0, 4, 7, 3	; 3

modelData2Vertex
		VERTEX_DATA	 -50, 100,  50	; 0
		VERTEX_DATA	  50, 100,  50	; 1
		VERTEX_DATA	  50, 100, -50	; 2
		VERTEX_DATA	 -50, 100, -50	; 3

		VERTEX_DATA	 -50,-100,  50	; 4
		VERTEX_DATA	  50,-100,  50	; 5
		VERTEX_DATA	  50,-100, -50	; 6
		VERTEX_DATA	 -50,-100, -50	; 7


;----------------------------
vramClearData:
		.db	$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,\
			$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00


;----------------------------
polygonColor:
		.db	$00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF,\
			$00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $55, $FF, $55, $00, $AA, $FF, $FF,\
			$00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF,\
			$00, $00, $00, $FF, $00, $FF, $00, $FF, $00, $AA, $FF, $AA, $00, $55, $FF, $FF

		.db	$00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $00, $FF, $FF,\
			$00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $55, $FF, $55, $00, $AA, $FF, $FF,\
			$00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $00, $FF, $FF,\
			$00, $00, $FF, $FF, $00, $00, $FF, $FF, $00, $AA, $FF, $AA, $00, $55, $FF, $FF

		.db	$00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $FF, $FF, $FF, $FF,\
			$00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, $55, $FF, $55, $00, $AA, $FF, $FF,\
			$00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, $00, $00, $00, $FF, $FF, $FF, $FF,\
			$00, $00, $00, $00, $FF, $FF, $FF, $FF, $00, $AA, $FF, $AA, $00, $55, $FF, $FF

		.db	$00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,\
			$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $AA, $FF, $FF, $FF, $FF,\
			$00, $00, $00, $00, $00, $00, $00, $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF,\
			$00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $55, $FF, $FF, $FF, $FF


;----------------------------
paletteData:
;0000000G GGRRRBBB
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF

		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF
		.dw	$0000, $0020, $0100, $0120, $0004, $0024, $0104, $0124,\
			$01B6, $0038, $01C0, $01F8, $0007, $003F, $01C7, $01FF


;----------------------------
;interrupt vectors
		.org	$FFF6

		.dw	_irq2
		.dw	_irq1
		.dw	_timer
		.dw	_nmi
		.dw	_reset


;////////////////////////////
;use bank1 to bank31
		INCLUDE	"poly_proc.asm"
