#include "stm32f10x.h"
#include "stm32f10x_tim.h"
#include "stm32f10x_gpio.h"
#include "stm32f10x_rcc.h"
/*
TIMER2 VA TIMER3 DUNG CHUNG CLOCK:
TIMER2 360xt = T (NGAT t   LAN VOI PERIOD 360)
TIMER3 tx360 = T (NGAT 360 LAN VOI PERIOD t)
LAY TIMER 2 DEM TU 0->359, TRAN THI TANG BIEN AUTO_ADJ
LAY AUTO_ADJ DUNG CHO TIMER3 
*/

uint16_t display_matrix[360];                //Bang hien thi

/*
uint16_t hour_hand[8]={0x04,0x06,0xffff,0x06,0x04};
uint16_t min_hand[8]={0xff80,0xffc0,0xff80};
uint16_t sec_hand[8]={0x80,0xc0,0xfff0,0xc0,0x80};
*/
uint16_t hour_hand[8]={0x03,0x03,0x03,0x03,0x03,0x03,0x03};
uint16_t min_hand[8]={0x10,0x10,0x10,0x10,0x10,0x10,0x10};
uint16_t sec_hand[8]={0x0040,0x0040,0x0040,0x0040,0x0040};
uint16_t font_data_table[255][8]={
																					{0x1000,0x1000,0x1000,0x1000,0x1000,0x1000,0x1000,0x1000},						//0
																					{0x0800,0x0800,0x0800,0x0800,0x0800,0x0800,0x0800,0x0800},							//1
																					{0x4000,0x4000,0x4000,0x4000,0x4000,0x4000,0x4000,0x4000}				//2
																				};




void GPIO_Config(void);
void TIM_Config(void);
void RCC_Config(void);
void Put_16bits(uint16_t data_16bd);
void NVIC_Config(void);
uint8_t Font_conversion(char font_data);
void UpdateString(char *str,uint8_t font_pos);
void ClearDisplay(void);

GPIO_InitTypeDef caidat_GPIO;
TIM_TimeBaseInitTypeDef  caidat_chung_TIM;

volatile uint16_t colum_val=0, round_val=0, auto_adjust_val=0;
volatile uint16_t previous_adjust_val = 0;



																			
/***************************************************************
*MAIN PROCESSING
*
*/

int main(void)
{
	
	
	RCC_Config();
	GPIO_Config();
	TIM_Config();
	NVIC_Config();
	
	while(1)
	{
		
		
		if(TIM3->CNT >previous_adjust_val)   //Ty le sang/tat
		{
			Put_16bits(0);
		}
		else 
		{
			Put_16bits(display_matrix[colum_val]);
			
		}
		
	}
	
	
}


/**********************************************************************************
* CONFIGURATIONS
*
*/

void RCC_Config(void)
{
	
	RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM2|RCC_APB1Periph_TIM3, ENABLE);
	RCC_APB2PeriphClockCmd(RCC_APB2Periph_GPIOA|RCC_APB2Periph_GPIOB|RCC_APB2Periph_AFIO,ENABLE);
}

void TIM_Config(void)
{
	TIM_TimeBaseStructInit(&caidat_chung_TIM);
	caidat_chung_TIM.TIM_CounterMode	=	TIM_CounterMode_Up;
	caidat_chung_TIM.TIM_ClockDivision		=	TIM_CKD_DIV1;
	caidat_chung_TIM.TIM_Prescaler				=	0;																					//prescaler =23+1 =24
	caidat_chung_TIM.TIM_Period						=	359;                                      //divides the cycle into 360 colums
	caidat_chung_TIM.TIM_RepetitionCounter	= 0x0000;
	
	TIM_TimeBaseInit(TIM2, &caidat_chung_TIM);
	TIM_TimeBaseInit(TIM3, &caidat_chung_TIM);
	
	TIM_Cmd(TIM2,ENABLE);
	TIM_Cmd(TIM3,ENABLE);
	TIM_ITConfig(TIM2,TIM_IT_Update,ENABLE);								//Set timer IT update enable
	TIM_ITConfig(TIM3,TIM_IT_Update,ENABLE);
	
}

void GPIO_Config(void)
{
	
	EXTI_InitTypeDef ngat_EXTI;
	
	GPIO_StructInit(&caidat_GPIO);
	caidat_GPIO.GPIO_Mode = GPIO_Mode_Out_PP;
	caidat_GPIO.GPIO_Speed = GPIO_Speed_50MHz;
	caidat_GPIO.GPIO_Pin     =	GPIO_Pin_0|GPIO_Pin_1|GPIO_Pin_2|GPIO_Pin_3|GPIO_Pin_4|GPIO_Pin_5|GPIO_Pin_6|GPIO_Pin_7|
																			GPIO_Pin_8|GPIO_Pin_9|GPIO_Pin_10|GPIO_Pin_11|GPIO_Pin_12|GPIO_Pin_13|GPIO_Pin_14|GPIO_Pin_15;
	
	GPIO_Init(GPIOB,&caidat_GPIO);											//GPIOB pins
	GPIO_PinRemapConfig(GPIO_Remap_SWJ_NoJTRST,ENABLE);				//Set PB4 to IO mode
	GPIO_PinRemapConfig(GPIO_Remap_SWJ_JTAGDisable,ENABLE);		//Set PB3 to IO mode
	
	Put_16bits(0);
	
	caidat_GPIO.GPIO_Mode	=GPIO_Mode_IN_FLOATING;
	caidat_GPIO.GPIO_Pin	= GPIO_Pin_1;
	GPIO_Init(GPIOA,&caidat_GPIO);
	
	GPIO_EXTILineConfig(GPIO_PortSourceGPIOA,GPIO_PinSource1);     // Port A - Pin 1
	ngat_EXTI.EXTI_Line = EXTI_Line1;
	ngat_EXTI.EXTI_Mode = EXTI_Mode_Interrupt;
	ngat_EXTI.EXTI_Trigger = EXTI_Trigger_Falling;    // Falling or Rising edg set up
	ngat_EXTI.EXTI_LineCmd = ENABLE;
	EXTI_Init(&ngat_EXTI);

	
}
void NVIC_Config(void)
{
	NVIC_InitTypeDef uu_tien_NVIC;
	NVIC_PriorityGroupConfig(NVIC_PriorityGroup_2);           //2bit cho uu tien preemption, 2 bit cho uu tien subpriority
																																					//By default, Priority is group 2, 2bit for preemption, 2bit for subpriority
	
	uu_tien_NVIC.NVIC_IRQChannel  = EXTI1_IRQn;
	uu_tien_NVIC.NVIC_IRQChannelPreemptionPriority = 0x00;       // nhom muc uu cao nhat
	uu_tien_NVIC.NVIC_IRQChannelSubPriority = 0x03;           // uu tien thap nhat trong nhom uu tien cao
	uu_tien_NVIC.NVIC_IRQChannelCmd = ENABLE;
	NVIC_Init(&uu_tien_NVIC);
	
	uu_tien_NVIC.NVIC_IRQChannel = TIM2_IRQn;
	uu_tien_NVIC.NVIC_IRQChannelPreemptionPriority = 0x01;
	uu_tien_NVIC.NVIC_IRQChannelSubPriority = 0x01;
	NVIC_Init(&uu_tien_NVIC);
	uu_tien_NVIC.NVIC_IRQChannel = TIM3_IRQn;
	NVIC_Init(&uu_tien_NVIC);
	
}


/***************************************************************
* PROCESSING 
*
*/

void ClearDisplay(void)
{
	uint16_t i;
	for(i=0;i<360;i++)           //Clear all previous data
	{
		display_matrix[i] &=0;
	}
}

void Update_Time(void)
{
	
	uint16_t i,hour_val=11,min_val=15,sec_val=40;
	uint16_t hour_pos,min_pos,sec_pos;
	
	
	hour_pos = hour_val*30 + min_val/2;
	min_pos = min_val*6;
	sec_pos = sec_val*6;
	
		for(i=0;i<8;i++)             // update new position of time hands
		{
		
			display_matrix[hour_pos+i] |= hour_hand[i];
			display_matrix[min_pos+i] |= min_hand[i];
			display_matrix[sec_pos+i] |= sec_hand[i];
		}
	
	
}

void Put_16bits(uint16_t data_16bd)
{

	GPIOB ->ODR = ~data_16bd;   			//Put data to port B
	
}



//---------FONT DISPLAY---------------------
//Chuyen doi font ASCII sang ma font hien thi
//Gia tri tra ve la bang tham chieu font trong font table
//Vi du, Font_conversion('a'); se tra ve 10

uint8_t Font_conversion(char font_data)
{
	uint8_t font_index;
	switch(font_data)
	{
		case '0': 
			font_index =0;
		break;
		
		case '1':
			font_index = 1;	
		break;
		
		case '2':
			font_index = 2;
		break;
		
		case '3':
			font_index = 3;
		break;
		
		case '4':
			font_index = 4;
		break;
		
		case '5':
			font_index = 5;
		break;
		
		default:
			font_index = 255;
		break;
		
	}
	return font_index;
		
}
	
void UpdateString(char *str,uint8_t font_pos)
{
	
	uint8_t j;
	uint8_t font_index;
	
	while(*str)
	{
		
		font_index = Font_conversion(*str);
		
		for(j=0;j<8;j++)
		{
			display_matrix[font_pos*8+j] |= font_data_table[font_index][j]; 	//Chuyen doi mang 2 chieu ve 1 chieu
			
		}
		
		font_pos ++;
		str++;
	}
	
}

//---------End of font display-----------------------

/****************************************************************
* INTERRUPT PROCESSING
*
*
*/


void TIM2_IRQHandler(void)
{
	if(TIM_GetITStatus(TIM2, TIM_IT_Update) != RESET)
	{
		TIM_ClearITPendingBit(TIM2,TIM_IT_Update);
		/*
		*/
		auto_adjust_val++;
		
		/*
		*/
		
	}
}

void TIM3_IRQHandler(void)
{
	
	if(TIM_GetITStatus(TIM3,TIM_IT_Update) != RESET)
	{
		TIM_ClearITPendingBit(TIM3,TIM_IT_Update);
	
		colum_val++;
		if(colum_val>359) colum_val=0;											
		
	}

}

void EXTI1_IRQHandler(void)
{
	if(EXTI_GetITStatus(EXTI_Line1) != RESET)
	{
		/*
		*	@{
		*/
		
		colum_val=0;
		
		TIM_Cmd(TIM3,DISABLE);              									// Stop TIM3
		caidat_chung_TIM.TIM_Period = auto_adjust_val; 		//Update new conter value
		previous_adjust_val = auto_adjust_val*17/20;						//Tu dong dieu chinh delay, ty le sang
		auto_adjust_val=0;
		
		TIM_TimeBaseInit(TIM3,&caidat_chung_TIM);
		TIM_Cmd(TIM3,ENABLE);
		
		//CAP NHAT THONG TIN VAO BANG
		ClearDisplay();
		Update_Time();
		UpdateString("012",0);
		/*
		*	}@
		*/
		EXTI_ClearITPendingBit(EXTI_Line1);
	}
	
}

