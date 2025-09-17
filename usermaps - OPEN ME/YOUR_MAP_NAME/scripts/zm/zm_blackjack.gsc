#using scripts\shared\util_shared;
#using scripts\shared\array_shared;
#insert scripts\shared\shared.gsh;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_score;
#using scripts\zm\zm_usermap;
#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm_powerups;
#using scripts\codescripts\struct;
/*
    Simple Blackjack V 1.0
    Credit if used: coolyer
    Setup:
      1. Place trigger_use entities with targetname: blackjack_table
      2. In your map function main():  
        thread zm_blackjack::init_blackjack();
        
    Controls during a hand:
      (F)Use = Hit
      Crouch = Stand
    

    In your zone file 
    1. include,zm_blackjack
*/

#define BJ_BET_COST  500                    // Cost to play one hand of blackjack
#define BJ_BLACKJACK_PAYOUT_NUM 3           // Numerator for blackjack payout (3:2 payout)
#define BJ_BLACKJACK_PAYOUT_DEN 2           // Denominator for blackjack payout (3:2 payout)
#define BJ_DEALER_STAND  17                 // Dealer stands on 17 or higher
#define BJ_MESSAGE_TIME  2.0                // Time (in seconds) to display end-of-hand messages
#define BJ_SHOW_TOTALS true                 // Show player/dealer card totals on HUD (set to false to hide)
#define BJ_DEALER_SPEED 1.5                 // Time (in seconds) between dealer actions (increase for more suspense)

// Sounds if you use the Slots as well change these.

#define BJ_SOUND_WIN   "slot_win_jingle" 
#define BJ_SOUND_LOSE  "slot_lose_buzz"
#define BJ_SOUND_PUSH  "slot_reel_stop"
#define BJ_SOUND_BJ    "slot_win_jingle"


#precache("material", "2_of_clubs");
#precache("material", "3_of_clubs");
#precache("material", "4_of_clubs");
#precache("material", "5_of_clubs");
#precache("material", "6_of_clubs");
#precache("material", "7_of_clubs");
#precache("material", "8_of_clubs");
#precache("material", "9_of_clubs");
#precache("material", "10_of_clubs");
#precache("material", "jack_of_clubs");
#precache("material", "queen_of_clubs");
#precache("material", "king_of_clubs");
#precache("material", "ace_of_clubs");
#precache("material", "2_of_hearts");
#precache("material", "3_of_hearts");
#precache("material", "4_of_hearts");
#precache("material", "5_of_hearts");
#precache("material", "6_of_hearts");
#precache("material", "7_of_hearts");
#precache("material", "8_of_hearts");
#precache("material", "9_of_hearts");
#precache("material", "10_of_hearts");
#precache("material", "jack_of_hearts");
#precache("material", "queen_of_hearts");
#precache("material", "king_of_hearts");
#precache("material", "ace_of_hearts");
#precache("material", "2_of_spades");
#precache("material", "3_of_spades");
#precache("material", "4_of_spades");
#precache("material", "5_of_spades");
#precache("material", "6_of_spades");
#precache("material", "7_of_spades");
#precache("material", "8_of_spades");
#precache("material", "9_of_spades");
#precache("material", "10_of_spades");
#precache("material", "jack_of_spades");
#precache("material", "queen_of_spades");
#precache("material", "king_of_spades");
#precache("material", "ace_of_spades");
#precache("material", "2_of_diamonds");
#precache("material", "3_of_diamonds");
#precache("material", "4_of_diamonds");
#precache("material", "5_of_diamonds");
#precache("material", "6_of_diamonds");
#precache("material", "7_of_diamonds");
#precache("material", "8_of_diamonds");
#precache("material", "9_of_diamonds");
#precache("material", "10_of_diamonds");
#precache("material", "jack_of_diamonds");
#precache("material", "queen_of_diamonds");
#precache("material", "king_of_diamonds");
#precache("material", "ace_of_diamonds");
#precache("material", "sleeve");

function init_blackjack()
{
    tables = GetEntArray("blackjack_table", "targetname");
    for(i = 0; i < tables.size; i++)
    {
        tables[i] SetHintString("^3Press &&1 to play Blackjack");
        tables[i].bj_in_use = false;
        tables[i] thread blackjack_table_think();
    }
}

function blackjack_table_think()
{
    trig = self;
    while(1)
    {
        trig waittill("trigger", player);

        // If already in use, optionally notify
        if(trig.bj_in_use)
        {
            //player IPrintLnBold("Blackjack table in use.");
            continue;
        }

        if(!isDefined(player.bj_busy))
        {
            trig.bj_in_use = true;
            trig SetHintString("^1In Use");
            player.bj_busy = true;
            player thread play_blackjack_hand(trig);
        }
    }
}

function play_blackjack_hand(trig)
{
    player = self;
    
    // Show betting HUD and wait for confirmation
    min_bet = 100;
    max_bet = player.score;
    default_bet = 500;
    show_blackjack_bet_hud(player, min_bet, max_bet, default_bet);

    bet = undefined;
    while(!isDefined(bet))
    {
        player waittill("blackjack_bet_confirmed", bet);
    }

    if(player.score < bet)
    {
        player IPrintLnBold("Need " + bet + " points.");
        player.bj_busy = undefined;
        trig.bj_in_use = false;
        trig SetHintString("^3Press &&1 to play Blackjack [^2" + bet + "^7]");
        return;
    }
    player.score -= Int(bet);

    deck = make_shuffled_deck();  // deck is a struct: deck.cards, deck.next

    self.bj_player_hand = [];
    self.bj_dealer_hand = [];

    // Initial deal
    self.bj_player_hand[self.bj_player_hand.size] = draw_card(deck);
    self.bj_dealer_hand[self.bj_dealer_hand.size] = draw_card(deck);
    self.bj_player_hand[self.bj_player_hand.size] = draw_card(deck);
    self.bj_dealer_hand[self.bj_dealer_hand.size] = draw_card(deck);

    hud = create_blackjack_hud(self);
    update_blackjack_hud(self, hud, false);

    p_val = hand_value(self.bj_player_hand);

    // Only end immediately if player has blackjack
    if(p_val.blackjack)
    {
        update_blackjack_hud(self, hud, true);
        wait(1.0); // Show player's blackjack for a moment
        end_blackjack_showdown(self, hud, true, bet);
        cleanup_blackjack_hand(player, trig, hud);
        return;
    }

    // Flush the activation key so holding Use to start does NOT auto-hit
    flush_use_input(self);

    // Enter player decision loop
    while(1)
    {
        p_val = hand_value(self.bj_player_hand);
        if(p_val.total >= 21)
            break;

        hud.status SetText("^3Use = Hit | Crouch = Stand");
        wait(0.05);

        if(self UseButtonPressed())
        {
            self.bj_player_hand[self.bj_player_hand.size] = draw_card(deck);
            update_blackjack_hud(self, hud, false);
            wait(0.2);
            continue;
        }

        if(self GetStance() == "crouch")
            break;
    }

    p_val = hand_value(self.bj_player_hand);
    if(p_val.total > 21)
    {
        end_blackjack_showdown(self, hud, true, bet); // Show big message for bust
        cleanup_blackjack_hand(player, trig, hud);
        return;
    }

    // Reveal dealer's hand
    update_blackjack_hud(self, hud, true);
    wait(1.0); // Give the player a moment to see the dealer's full hand

    d_val = hand_value(self.bj_dealer_hand);
    if(d_val.blackjack)
    {
        end_blackjack_showdown(self, hud, true, bet); // Dealer has blackjack, show message
        cleanup_blackjack_hand(player, trig, hud);
        return;
    }

    // Dealer plays as normal if no blackjack
    wait(BJ_DEALER_SPEED); 
    while(1)
    {
        d_val = hand_value(self.bj_dealer_hand);
        if(d_val.total >= BJ_DEALER_STAND)
            break;
        self.bj_dealer_hand[self.bj_dealer_hand.size] = draw_card(deck);
        update_blackjack_hud(self, hud, true);
        wait(BJ_DEALER_SPEED);
    }

    end_blackjack_showdown(self, hud, true, bet);
    cleanup_blackjack_hand(player, trig, hud);
}

function cleanup_blackjack_hand(player, trig, hud)
{
    destroy_blackjack_hud(hud);
    player.bj_busy = undefined;
    trig.bj_in_use = false;
    trig SetHintString("^3Press &&1 to play Blackjack");
}

function end_blackjack_showdown(player, hud, reveal, bet)
{
    update_blackjack_hud(player, hud, reveal);

    p_val = hand_value(player.bj_player_hand);
    d_val = hand_value(player.bj_dealer_hand);

    msg = "";
    payout = 0;
    sound_to_play = BJ_SOUND_WIN; // Default to win sound

    if(p_val.blackjack && d_val.blackjack)
    {
        msg = "^5Push: Double Blackjack";
        player.score += Int(bet); // Refund only
        sound_to_play = BJ_SOUND_PUSH;
    }
    else if(p_val.blackjack)
    {
        msg = "^2Blackjack! You win!";
        payout = Int((bet * 3) / 2); // 3:2 payout (winnings only, as int)
        player.score += Int(bet + payout); // Refund bet + winnings
        sound_to_play = BJ_SOUND_BJ;
    }
    else if(d_val.blackjack)
    {
        msg = "^1Dealer Blackjack";
        sound_to_play = BJ_SOUND_LOSE;
    }
    else if(p_val.total > 21)
    {
        msg = "^1Bust! Dealer wins.";
        sound_to_play = BJ_SOUND_LOSE;
    }
    else if(d_val.total > 21)
    {
        msg = "^2Dealer Bust";
        payout = Int(bet); // winnings only
        player.score += Int(bet + payout); // Refund bet + winnings
    }
    else if(p_val.total > d_val.total)
    {
        msg = "^2You Win";
        payout = Int(bet); // winnings only
        player.score += Int(bet + payout); // Refund bet + winnings
    }
    else if(p_val.total < d_val.total)
    {
        msg = "^1Dealer Wins";
        sound_to_play = BJ_SOUND_LOSE;
    }
    else
    {
        msg = "^5Push";
        player.score += Int(bet); // Refund only
        sound_to_play = BJ_SOUND_PUSH;
    }

    // --- BIG CENTERED MESSAGE ---
    bigmsg = NewClientHudElem(player);
    bigmsg.alignX = "center";
    bigmsg.alignY = "middle";
    bigmsg.horzAlign = "center";
    bigmsg.vertAlign = "middle";
    bigmsg.x = 0;
    bigmsg.y = -40;
    bigmsg.fontScale = 1.5;
    bigmsg SetText(msg + (payout > 0 ? " (^3+" + payout + "^7)" : ""));

    // Destroy cards and HUD immediately
    destroy_blackjack_hud(hud);

    // Play the sound!
    player PlayLocalSound(sound_to_play);

    // Keep the big message up for about 1 second
    wait(1.0);

    bigmsg Destroy();
}

function make_shuffled_deck()
{
    ranks = array("2","3","4","5","6","7","8","9","10","J","Q","K","A");
    suits = array("clubs", "hearts", "spades", "diamonds");

    d = spawnstruct();
    d.cards = [];
    d.next = 0;

    // Build 52 cards
    for(s = 0; s < suits.size; s++)
    {
        for(r = 0; r < ranks.size; r++)
        {
            card = spawnstruct();
            card.rank = ranks[r];
            card.suit = suits[s];
            if(ranks[r] == "A")
                card.value = 11;
            else if(ranks[r] == "J" || ranks[r] == "Q" || ranks[r] == "K" || ranks[r] == "10")
                card.value = 10;
            else
                card.value = Int(ranks[r]);
            d.cards[d.cards.size] = card;
        }
    }

    // Fisher‑Yates shuffle
    for(i = d.cards.size - 1; i > 0; i--)
    {
        j = RandomInt(i + 1);
        temp = d.cards[i];
        d.cards[i] = d.cards[j];
        d.cards[j] = temp;
    }
    return d;
}

function draw_card(deck)
{
    if(!isDefined(deck) || !isDefined(deck.cards))
        return undefined;

    if(deck.next >= deck.cards.size)
        return undefined; // no more cards

    card = deck.cards[deck.next];
    deck.next++;
    return card;
}

function hand_value(hand)
{
    total = 0;
    aces = 0;
    for(i = 0; i < hand.size; i++)
    {
        total += hand[i].value;
        if(hand[i].rank == "A")
            aces++;
    }
    // Adjust Aces from 11 to 1 as needed
    while(total > 21 && aces > 0)
    {
        total -= 10;
        aces--;
    }

    result = spawnstruct();
    result.total = total;
    result.blackjack = (hand.size == 2 && total == 21);
    return result;
}

function create_blackjack_hud(player)
{
    hud = spawnstruct();

    // Dealer label
    hud.dealer_label = NewClientHudElem(player);
    hud.dealer_label.alignX = "center";
    hud.dealer_label.alignY = "middle";
    hud.dealer_label.horzAlign = "center";
    hud.dealer_label.vertAlign = "middle";
    hud.dealer_label.y = -180; // stays at top
    hud.dealer_label.fontScale = 1.0;
    hud.dealer_label SetText("^1Dealer's Cards");

    // Player label
    hud.player_label = NewClientHudElem(player);
    hud.player_label.alignX = "center";
    hud.player_label.alignY = "middle";
    hud.player_label.horzAlign = "center";
    hud.player_label.vertAlign = "middle";
    hud.player_label.y = 0; // move further down
    hud.player_label.fontScale = 1.0;
    hud.player_label SetText("^2Your Cards");

    // Status/instructions
    hud.status = NewClientHudElem(player);
    hud.status.alignX = "center";
    hud.status.alignY = "middle";
    hud.status.horzAlign = "center";
    hud.status.vertAlign = "middle";
    hud.status.y = 120; // move even lower
    hud.status.fontScale = 1.2;

    if (IS_TRUE(BJ_SHOW_TOTALS)){
        hud.totals = NewClientHudElem(player);
        hud.totals.alignX = "right";
        hud.totals.alignY = "middle";
        hud.totals.horzAlign = "right";
        hud.totals.vertAlign = "middle";
        hud.totals.x = -40;
        hud.totals.y = 0;
        hud.totals.fontScale = 1.2;
    }
    return hud;
}

function update_blackjack_hud(player, hud, reveal_dealer)
{
    // Remove old card images if they exist
    if(isDefined(hud.player_card_imgs))
    {
        for(i = 0; i < hud.player_card_imgs.size; i++)
            if(isDefined(hud.player_card_imgs[i])) hud.player_card_imgs[i] Destroy();
    }
    hud.player_card_imgs = undefined; 

    // Draw player cards as images
    hud.player_card_imgs = [];
    for(i = 0; i < player.bj_player_hand.size; i++)
    {
        card = player.bj_player_hand[i];
        mat = card_to_material(card, card.suit);
        img = NewClientHudElem(player);
        img.alignX = "center";
        img.alignY = "middle";
        img.horzAlign = "center";
        img.vertAlign = "middle";
        img.x = -((player.bj_player_hand.size-1)*40) + i*80;
        img.y = 40; // just below "Your Cards" label
        img SetShader(mat, 64, 64);
        hud.player_card_imgs[hud.player_card_imgs.size] = img;
    }

    // Remove old dealer card images if they exist
    if(isDefined(hud.dealer_card_imgs))
    {
        for(i = 0; i < hud.dealer_card_imgs.size; i++)
            if(isDefined(hud.dealer_card_imgs[i])) hud.dealer_card_imgs[i] Destroy();
    }
    hud.dealer_card_imgs = undefined; 

    // Draw dealer cards as images
    hud.dealer_card_imgs = [];
    for(i = 0; i < player.bj_dealer_hand.size; i++)
    {
        card = player.bj_dealer_hand[i];
        img = NewClientHudElem(player);
        img.alignX = "center";
        img.alignY = "middle";
        img.horzAlign = "center";
        img.vertAlign = "middle";
        img.x = -((player.bj_dealer_hand.size-1)*40) + i*80;
        img.y = -140; // just below "Dealer's Cards" label
        if(i == 0 || reveal_dealer)
        {
            mat = card_to_material(card, card.suit);
            img SetShader(mat, 64, 64);
        }
        else
        {
            img SetShader("sleeve", 64, 64);
        }
        hud.dealer_card_imgs[hud.dealer_card_imgs.size] = img;
    }

    // Status text
    p_val = hand_value(player.bj_player_hand).total;
    if(reveal_dealer)
        d_val = hand_value(player.bj_dealer_hand).total;
    else
        d_val = "?";
    hud.status SetText("^2You: ^3" + p_val + "   ^1Dealer: ^3" + d_val);
    if (IS_TRUE(BJ_SHOW_TOTALS))
    {
        p_val = hand_value(player.bj_player_hand).total;
        if(reveal_dealer)
            d_val = hand_value(player.bj_dealer_hand).total;
        else
            d_val = "?";
        hud.totals SetText("^2Your Total: ^3" + p_val + "\n^1Dealer: ^3" + d_val);
    }
}

function cards_to_string(hand)
{
    out = "";
    for(i = 0; i < hand.size; i++)
    {
        if(i > 0)
            out += " ";
        out += hand[i].rank;
    }
    return out;
}

function destroy_blackjack_hud(hud)
{
    if(isDefined(hud.player_cards)) hud.player_cards Destroy();
    if(isDefined(hud.dealer_cards)) hud.dealer_cards Destroy();
    if(isDefined(hud.status)) hud.status Destroy();

    // Destroy player card images
    if(isDefined(hud.player_card_imgs))
    {
        for(i = 0; i < hud.player_card_imgs.size; i++)
            if(isDefined(hud.player_card_imgs[i])) hud.player_card_imgs[i] Destroy();
        hud.player_card_imgs = undefined; 
    }

    // Destroy dealer card images
    if(isDefined(hud.dealer_card_imgs))
    {
        for(i = 0; i < hud.dealer_card_imgs.size; i++)
            if(isDefined(hud.dealer_card_imgs[i])) hud.dealer_card_imgs[i] Destroy();
        hud.dealer_card_imgs = undefined; 
    }
    if (IS_TRUE(BJ_SHOW_TOTALS))
    {
        if(isDefined(hud.totals)) hud.totals Destroy();
    }
    if(isDefined(hud.dealer_label)) hud.dealer_label Destroy();
    if(isDefined(hud.player_label)) hud.player_label Destroy();
}

function flush_use_input(player)
{
    // Wait for any still-held Use from the trigger press to be released
    t = GetTime();
    // Max 1 second safety
    while(player UseButtonPressed() && GetTime() - t < 1000)
        wait(0.05);
}

function card_to_material(card, suit)
{
    // card.rank: "2", "3", ..., "10", "J", "Q", "K", "A"
    // suit: "clubs", "hearts", "spades", "diamonds"
    rank = card.rank;
    if(rank == "J") rank = "jack";
    else if(rank == "Q") rank = "queen";
    else if(rank == "K") rank = "king";
    else if(rank == "A") rank = "ace";
    return rank + "_of_" + suit;
}

function show_blackjack_bet_hud(player, min_bet, max_bet, default_bet)
{
    hud = spawnstruct();

    hud.bet_text = NewClientHudElem(player);
    hud.bet_text.alignX = "center";
    hud.bet_text.alignY = "middle";
    hud.bet_text.horzAlign = "center";
    hud.bet_text.vertAlign = "middle";
    hud.bet_text.x = 0;
    hud.bet_text.y = -60;
    hud.bet_text.fontScale = 1.5;
    hud.bet_text SetText("^3Blackjack Bet: ^2" + default_bet + "\n^7Use = Increase | Crouch = Decrease | Melee = Confirm");

    hud.current_bet = default_bet;

    player thread blackjack_bet_input(hud, min_bet, max_bet);

    return hud;
}

function blackjack_bet_input(hud, min_bet, max_bet)
{
    player = self;
    while(1)
    {
        if(player UseButtonPressed())
        {
            hud.current_bet = min(hud.current_bet + 100, max_bet);
            hud.bet_text SetText("^3Blackjack Bet: ^2" + hud.current_bet + "\n^7Use = Increase | Crouch = Decrease | Melee = Confirm");
            wait(0.2);
        }
        else if(player GetStance() == "crouch")
        {
            hud.current_bet = max(hud.current_bet - 100, min_bet);
            hud.bet_text SetText("^3Blackjack Bet: ^2" + hud.current_bet + "\n^7Use = Increase | Crouch = Decrease | Melee = Confirm");
            wait(0.2);
        }
        else if(player MeleeButtonPressed())
        {
            break;
        }
        wait(0.05);
    }
    player notify("blackjack_bet_confirmed", hud.current_bet);
    hud.bet_text Destroy();
}

