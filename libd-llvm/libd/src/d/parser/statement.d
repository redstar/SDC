module d.parser.statement;

import d.ast.statement;
import d.ast.expression;

import d.parser.base;
import d.parser.conditional;
import d.parser.declaration;
import d.parser.expression;
import d.parser.type;
import d.parser.util;

import sdc.location;
import sdc.token;

import std.array;
import std.range;

Statement parseStatement(TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange) {
	Location location = trange.front.location;
	
	switch(trange.front.type) {
		case TokenType.OpenBrace :
			return trange.parseBlock();
		
		case TokenType.If :
			trange.popFront();
			trange.match(TokenType.OpenParen);
			
			auto condition = trange.parseExpression();
			
			trange.match(TokenType.CloseParen);
			
			auto then = trange.parseStatement();
			
			if(trange.front.type == TokenType.Else) {
				trange.popFront();
				auto elseStatement = trange.parseStatement();
				
				location.spanTo(elseStatement.location);
				
				return new IfElseStatement(location, condition, then, elseStatement);
			}
			
			location.spanTo(then.location);
			return new IfStatement(location, condition, then);
		
		case TokenType.While :
			trange.popFront();
			trange.match(TokenType.OpenParen);
			auto condition = trange.parseExpression();
			
			trange.match(TokenType.CloseParen);
			
			auto statement = trange.parseStatement();
			
			location.spanTo(statement.location);
			return new WhileStatement(location, condition, statement);
		
		case TokenType.Do :
			trange.popFront();
			
			auto statement = trange.parseStatement();
			
			trange.match(TokenType.While);
			trange.match(TokenType.OpenParen);
			auto condition = trange.parseExpression();
			
			trange.match(TokenType.CloseParen);
			
			location.spanTo(trange.front.location);
			trange.match(TokenType.Semicolon);
			
			return new DoWhileStatement(location, condition, statement);
		
		case TokenType.For :
			trange.popFront();
			
			trange.match(TokenType.OpenParen);
			
			Statement init;
			if(trange.front.type == TokenType.Semicolon) {
				init = new BlockStatement(trange.front.location, []);
				trange.popFront();
			} else {
				init = trange.parseStatement();
			}
			
			auto condition = trange.parseExpression();
			trange.match(TokenType.Semicolon);
			
			auto increment = trange.parseExpression();
			trange.match(TokenType.CloseParen);
			
			auto statement = trange.parseStatement();
			
			location.spanTo(statement.location);
			return new ForStatement(location, init, condition, increment, statement);
		
		case TokenType.Foreach :
			trange.popFront();
			trange.match(TokenType.OpenParen);
			
			// Hack hack hack HACK !
			while(trange.front.type != TokenType.Semicolon) trange.popFront();
			
			trange.match(TokenType.Semicolon);
			trange.parseExpression();
			
			if(trange.front.type == TokenType.DoubleDot) {
				trange.popFront();
				trange.parseExpression();
			}
			
			trange.match(TokenType.CloseParen);
			
			trange.parseStatement();
			
			return null;
		
		case TokenType.Break :
			trange.popFront();
			
			if(trange.front.type == TokenType.Identifier) trange.popFront();
			
			location.spanTo(trange.front.location);
			trange.match(TokenType.Semicolon);
			
			return new BreakStatement(location);
		
		case TokenType.Continue :
			trange.popFront();
			
			if(trange.front.type == TokenType.Identifier) trange.popFront();
			
			location.spanTo(trange.front.location);
			trange.match(TokenType.Semicolon);
			
			return new ContinueStatement(location);
		
		case TokenType.Return :
			trange.popFront();
			
			Expression value;
			if(trange.front.type != TokenType.Semicolon) {
				value = trange.parseExpression();
			}
			
			location.spanTo(trange.front.location);
			trange.match(TokenType.Semicolon);
			
			return new ReturnStatement(location, value);
		
		case TokenType.Synchronized :
			trange.popFront();
			if(trange.front.type == TokenType.OpenParen) {
				trange.popFront();
				
				trange.parseExpression();
				
				trange.match(TokenType.CloseParen);
			}
			
			trange.parseStatement();
			
			return null;
		
		case TokenType.Try :
			trange.popFront();
			
			auto statement = trange.parseStatement();
			
			CatchBlock[] catches;
			while(trange.front.type == TokenType.Catch) {
				auto catchLocation = trange.front.location;
				trange.popFront();
				
				if(trange.front.type == TokenType.OpenParen) {
					trange.popFront();
					auto type = trange.parseBasicType();
					string name;
					
					if(trange.front.type == TokenType.Identifier) {
						name = trange.front.value;
						trange.popFront();
					}
					
					trange.match(TokenType.CloseParen);
					
					auto catchStatement = trange.parseStatement();
					
					location.spanTo(catchStatement.location);
					catches ~= new CatchBlock(location, type, name, catchStatement);
				} else {
					// TODO: handle final catches ?
					trange.parseStatement();
					break;
				}
			}
			
			if(trange.front.type == TokenType.Finally) {
				trange.popFront();
				auto finallyStatement = trange.parseStatement();
				
				location.spanTo(finallyStatement.location);
				return new TryFinallyStatement(location, statement, [], finallyStatement);
			}
			
			location.spanTo(catches.back.location);
			return new TryStatement(location, statement, []);
		
		case TokenType.Throw :
			trange.popFront();
			auto value = trange.parseExpression();
			
			location.spanTo(trange.front.location);
			trange.match(TokenType.Semicolon);
			
			return new ThrowStatement(location, value);
		
		case TokenType.Mixin :
			trange.popFront();
			trange.match(TokenType.OpenParen);
			trange.parseExpression();
			trange.match(TokenType.CloseParen);
			trange.match(TokenType.Semicolon);
			break;
		
		case TokenType.Static :
			auto lookahead = trange.save;
			lookahead.popFront();
			
			switch(lookahead.front.type) {
				case TokenType.If :
					return trange.parseStaticIf!Statement();
				
				case TokenType.Assert :
					trange.popFrontN(2);
					trange.match(TokenType.OpenParen);
					
					auto arguments = trange.parseArguments();
					
					trange.match(TokenType.CloseParen);
					
					location.spanTo(trange.front.location);
					trange.match(TokenType.Semicolon);
					
					return new StaticAssertStatement(location, arguments);
				
				default :
					return trange.parseDeclaration();
			}
		
		case TokenType.Version :
			return trange.parseVersion!Statement();
		
		case TokenType.Debug :
			return trange.parseDebug!Statement();
		
		default :
			if(trange.isDeclaration()) {
				return trange.parseDeclaration();
			} else {
				auto expression = trange.parseExpression();
				trange.match(TokenType.Semicolon);
				
				return expression;
			}
	}
	
	assert(0);
}

BlockStatement parseBlock(TokenRange)(ref TokenRange trange) if(isTokenRange!TokenRange) {
	Location location = trange.front.location;
	
	trange.match(TokenType.OpenBrace);
	
	Statement[] statements;
	
	while(trange.front.type != TokenType.CloseBrace) {
		statements ~= trange.parseStatement();
	}
	
	location.spanTo(trange.front.location);
	
	trange.popFront();
	
	return new BlockStatement(location, statements);
}

