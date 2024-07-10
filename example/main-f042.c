/*
 * SPDX-FileCopyrightText: 2023-2024 Rafael G. Martins <rafael@rafaelmartins.eng.br>
 * SPDX-License-Identifier: BSD-3-Clause
 */

// Blinks the user LED in NUCLEO-F042K6 @ 0.5Hz

#include <stm32f0xx.h>

#define clock_frequency 48000000


void
SysTick_Handler(void)
{
    static int counter = 0;
    if ((++counter % 1000) == 0)
        GPIOB->BSRR = (GPIOB->ODR & GPIO_ODR_3) ? GPIO_BSRR_BR_3 : GPIO_BSRR_BS_3;
}


void
clock_init(void)
{
    // 1 flash wait cycle required to operate @ 48MHz (RM0091 section 3.5.1)
    FLASH->ACR &= ~FLASH_ACR_LATENCY;
    FLASH->ACR |= FLASH_ACR_LATENCY;
    while ((FLASH->ACR & FLASH_ACR_LATENCY) != FLASH_ACR_LATENCY);

    RCC->CR2 |= RCC_CR2_HSI48ON;
    while ((RCC->CR2 & RCC_CR2_HSI48RDY) != RCC_CR2_HSI48RDY);

    RCC->CFGR &= ~(RCC_CFGR_HPRE | RCC_CFGR_PPRE | RCC_CFGR_SW);
    RCC->CFGR |= RCC_CFGR_HPRE_DIV1 | RCC_CFGR_PPRE_DIV1 | RCC_CFGR_SW_HSI48;
    while((RCC->CFGR & RCC_CFGR_SWS) != RCC_CFGR_SWS_HSI48);

    SysTick_Config(clock_frequency / 1000);
    SystemCoreClock = clock_frequency;
}


int
main(void)
{
    clock_init();

    RCC->AHBENR |= RCC_AHBENR_GPIOBEN;
    __asm volatile ("nop");
    __asm volatile ("nop");

    GPIOB->MODER &= ~GPIO_MODER_MODER3;
    GPIOB->MODER |= GPIO_MODER_MODER3_0;

    while (1);

    return 0;
}
